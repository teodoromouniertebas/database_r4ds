############################ Databases ###########################

library(DBI)
library(dbplyr)
library(tidyverse)


# connect to duckdb:
con <- DBI::dbConnect(duckdb::duckdb())
con <- DBI::dbConnect(duckdb::duckdb(), dbdir = "duckdb")

# Create a table:
dbWriteTable(con, "mpg", ggplot2::mpg)
dbWriteTable(con, "diamonds", ggplot2::diamonds)


# List name tables:
dbListTables(con)

# Read Table:
con |>
  dbReadTable("diamonds") |>
  as_tibble()

# First Query:
sql <- "
  SELECT carat, cut, clarity, color, price
  FROM diamonds
  WHERE price > 15000
"
as_tibble(dbGetQuery(con, sql))


# basics:
diamonds_db <- tbl(con, "diamonds")
diamonds_db

# other ways to connect ;
# diamonds_db <- tbl(con, in_schema("sales", "diamonds"))
# diamonds_db <- tbl(con, in_catalog("north_america", "sales", "diamonds"))


# basics
big_diamonds_db <- diamonds_db |>
  filter(price > 15000) |>
  select(carat:clarity, price)

big_diamonds_db

big_diamonds_db |>
  show_query()

big_diamonds <- big_diamonds_db |>
  collect()
big_diamonds


# other example:
dbplyr::copy_nycflights13(con)
flights <- tbl(con, "flights")
planes <- tbl(con, "planes")

flights |> show_query()
planes |> show_query()

flights |>
  filter(dest == "IAH") |>
  arrange(dep_delay) |>
  show_query()

flights |>
  group_by(dest) |>
  summarize(dep_delay = mean(dep_delay, na.rm = TRUE)) |>
  show_query()




################################## ARROW
library(tidyverse)
library(arrow)
library(dbplyr, warn.conflicts = FALSE)
library(duckdb)

# Create a folder:
dir.create("data", showWarnings = FALSE)

# Import data 9GB
# curl::multi_download(
#   "https://r4ds.s3.us-west-2.amazonaws.com/seattle-library-checkouts.csv",
#   "data/seattle-library-checkouts.csv",
#   resume = TRUE
# )

# Open data:
seattle_csv <- open_dataset(
  sources = "data/seattle-library-checkouts.csv",
  col_types = schema(ISBN = string()),
  format = "csv"
)
seattle_csv

seattle_csv |> glimpse()

# use collect:
seattle_csv |>
  group_by(CheckoutYear) |>
  summarise(Checkouts = sum(Checkouts)) |>
  arrange(CheckoutYear) |>
  collect()


# Parquet Format:
pq_path <- "data/seattle-library-checkouts"

# Partitionning data:
seattle_csv |>
  group_by(CheckoutYear) |>
  write_dataset(path = pq_path, format = "parquet")

# check the folders created:
tibble(
  files = list.files(pq_path, recursive = TRUE),
  size_MB = file.size(file.path(pq_path, files)) / 1024^2
)


seattle_pq <- open_dataset(pq_path)


query <- seattle_pq |>
  filter(CheckoutYear >= 2018, MaterialType == "BOOK") |>
  group_by(CheckoutYear, CheckoutMonth) |>
  summarize(TotalCheckouts = sum(Checkouts)) |>
  arrange(CheckoutYear, CheckoutMonth)

query |> collect()


# Comparing performance between csv and parquet format:
seattle_csv |>
  filter(CheckoutYear == 2021, MaterialType == "BOOK") |>
  group_by(CheckoutMonth) |>
  summarize(TotalCheckouts = sum(Checkouts)) |>
  arrange(desc(CheckoutMonth)) |>
  collect() |>
  system.time()

seattle_pq |>
  filter(CheckoutYear == 2021, MaterialType == "BOOK") |>
  group_by(CheckoutMonth) |>
  summarize(TotalCheckouts = sum(Checkouts)) |>
  arrange(desc(CheckoutMonth)) |>
  collect() |>
  system.time()


# Using duckdb with arrow:

seattle_pq |>
  to_duckdb() |>
  filter(CheckoutYear >= 2018, MaterialType == "BOOK") |>
  group_by(CheckoutYear) |>
  summarize(TotalCheckouts = sum(Checkouts)) |>
  arrange(desc(CheckoutYear)) |>
  collect()




################################## JSON
library(tidyverse)
library(repurrrsive)
library(jsonlite)


# List:
x1 <- list(1:4, "a", TRUE)
x1

# naming the childrens of the list:
x2 <- list(a = 1:2, b = 1:3, c = 1:4)
x2

# use str() to have a compact printing:
str(x1)
str(x2)

# Hierarchical data (lists in list):
x3 <- list(list(1, 2), list(3, 4))
str(x3)

# different of c() wich generate a vector:
c(c(1, 2), c(3, 4))
x4 <- c(list(1, 2), list(3, 4))
str(x4)

# str() very useful when list are getting complex:
x5 <- list(1, list(2, list(3, list(4, list(5)))))
str(x5)

# or use view()
View(x5)


# List-column (used in Tidymodel)
df <- tibble(
  x = 1:2,
  y = c("a", "b"),
  z = list(list(1, 2), list(3, 4, 5))
)
df


# exemples:
# when the list contain names with same names (better to use unnest_wider())
df1 <- tribble(
  ~x, ~y,
  1, list(a = 11, b = 12),
  2, list(a = 21, b = 22),
  3, list(a = 31, b = 32),
)

df1 |> unnest_wider(y)
df1 |> unnest_wider(y, names_sep = "_")

# When the list does't contain names (better to use unnest_longer())
df2 <- tribble(
  ~x, ~y,
  1, list(11, 12, 13),
  2, list(21),
  3, list(31, 32),
)

df2 |> unnest_longer(y)

# with an empty row
df6 <- tribble(
  ~x, ~y,
  "a", list(1, 2),
  "b", list(3),
  "c", list()
)
df6 |> unnest_longer(y)
df6 |> unnest_longer(y, keep_empty = TRUE)


# What happen with unconsistent type:
df4 <- tribble(
  ~x, ~y,
  "a", list(1),
  "b", list("a", TRUE, 5)
)

df4 |> unnest_longer(y)


# unnest_auto() chose between unnest_longer() or unnest_wider() depending on the data structure
# unnest() is doing both at the same time and is usefull when your list is a list of data.frames



# In real world:
json <- '[
  {"name": "John", "age": 34},
  {"name": "Susan", "age": 27}
]'
df <- tibble(json = parse_json(json))
df

df |> unnest_wider(json)


json <- '{
  "status": "OK",
  "results": [
    {"name": "John", "age": 34},
    {"name": "Susan", "age": 27}
 ]
}
'
df <- tibble(json = list(parse_json(json)))
df

df |>
  unnest_wider(json) |>
  unnest_longer(results) |>
  unnest_wider(results)


# A path to a json file inside the package:
gh_users_json()

# Read it with read_json()
gh_users <- read_json(gh_users_json())
repos <- tibble(json = gh_repos)
repos

# because no named lists (unnest_longer()):
repos |> unnest_longer(json)

# because named lists (unnest:wider()):
repos |>
  unnest_longer(json) |>
  unnest_wider(json)

repos |>
  unnest_longer(json) |>
  unnest_wider(json) |>
  names() |>
  head(10)

# because there is named list owner we use unnest_wider()
repos |>
  unnest_longer(json) |>
  unnest_wider(json) |>
  select(id, full_name, owner, description) |>
  unnest_wider(owner)

# if problems with id use, names sep to keep the name of the columns listed:
repos |>
  unnest_longer(json) |>
  unnest_wider(json) |>
  select(id, full_name, owner, description) |>
  unnest_wider(owner, names_sep = "_")
