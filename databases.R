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



