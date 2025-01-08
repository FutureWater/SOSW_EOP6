# SOS-Water Project - EOP6 Downscaling Snow Water Equivalent (SWE)
# Author: Tijmen Schults, Futurewater, t.schults@futurewater.nl
# Date: 2025-01-08

# Load necessary libraries and set working directory
packages <- c("terra", "randomForest", "caret", "tidyr",
              "ggplot2", "dplyr", "lubridate", "pbapply")
installed_packages <- packages %in% installed.packages()[, "Package"]
if (any(!installed_packages)) {
  install.packages(packages[!installed_packages])
}
lapply(packages, library, character.only = TRUE)

# Set working directory
setwd("/path/to/working/directory")

# Set seed for reproducibility
set.seed(123)

# Define simulation name
simulation_name <- "my_simulation"

# Define AOI and create a polygon layer
aoi <- terra::rast("aoi.tif") # Specify as raster
aoi_polygon <- as.polygons(aoi, na.rm = TRUE, dissolve = TRUE) # Or as vector

# Load predictors rasters used for building the training dataset
# Load static covariates (elevation, aspect, roughness, slope)
# All data should be provided in common spatial resolution and CRS
elevation <- terra::rast("evelevation.tif")
aspect <- terra::rast("aspect.tif")
roughness <- terra::rast("roughness.tif")
slope <- terra::rast("slope.tif")

# Load temporal covariate raster (daily ERA5-Land SWE rasterstack)
era5_full <- terra::rast("era5_land_swe.tif")

# Load stations vector containing locations of snow weather stations
# Should contain a column named 'station_number'
stations <- terra::vect("snow_stations.shp")

# Read snow water equivalent observations from CSV
# Should contain columns 'date', and SWE measurements for each 'station_number'
observations <- read.csv("snowcover.csv",
                         header = TRUE)

# Specify missing value in observations
na_value <- -999

# Create necessary directories 
output_directories <- c("output", paste0("output/", simulation_name),
                        paste0("output/", simulation_name, "/prediction"))

for (directory in output_directories) {
  if (!dir.exists(directory)) {
    dir.create(directory, recursive = TRUE)
  }
}

# User flags
create_new_dataset <- TRUE      # Flag to create a new dataset
train_new_model <- TRUE         # Flag to train a new RF model
do_predictions <- TRUE          # Flag to perform predictions

# Prediction date range
start_date <- "2001-01-01" 
end_date <- "2001-12-31"

# Define EOP6 core functions

# Function to create a training dataset
create_dataset <- function() {
  # Reshape the time series data into long format
  # Should have 3 columns (date, station_number, swe)
  long_obs <- tidyr::pivot_longer(
    observations, cols = -date, names_to = "station_number", values_to = "swe"
  )

  # Convert the 'date' column to YYYY-MM-DD type if it isn't already
  long_obs$date <- as.Date(
    long_obs$date, format = "%d/%m/%Y"
  )

  # Merge the time series data with station data on the 'station_number' column
  stations_df <- as.data.frame(stations, xy = TRUE)
  stations_df <- dplyr::rename(stations_df, x = lon, y = lat)
  merged_obs <- merge(
    long_obs, stations_df, by = "station_number"
  )

  # Sort the observations by date
  merged_obs <- merged_obs[
    order(merged_obs$date), 
  ]

  # Remove records missing values
  merged_obs <- dplyr::filter(
    merged_obs, swe != na_value
  )

  # Filter ERA5 dataset to only include dates where observations are available
  common_dates <- unique(merged_obs$date)
  era5_training <- subset(era5_full, time(era5_full) %in% common_dates)

  # Merge static covariates with station data to give it XY coordinates
  static_cov <- terra::extract(
    c(elevation, aspect, roughness, slope), stations, xy = TRUE
  )

  # Bind column of station numbers to static covariates
  static_cov <- cbind(static_cov, station_number = stations$station_number)

  # Generate training data for each day
  training_data <- do.call(rbind, pbapply::pblapply(
    seq_len(terra::nlyr(era5_training)), function(i) {
      temporal_data <- era5_training[[i]]

      # Extract temporal data
      temp_df <- terra::extract(temporal_data, stations, xy = TRUE)
      temp_df <- cbind(temp_df, station_number = stations$station_number)

      # Combine static and temporal data
      combined_df <- dplyr::inner_join(
        temp_df, static_cov, by = c("x", "y", "station_number")
      )

      # Drop unnecessary columns, might vary based on your data
      combined_df <- combined_df[, -c(1, 3, 4, 6)] 

      # Standardize column names
      colnames(combined_df) <- c(
        "swe_era5", "station_number", "elevation", "aspect", "roughness", "slope"
      )

      # Add date
      combined_df$date <- time(era5_training[[i]])
      return(combined_df)
    }
  ))

  # Combine observations with training data based on dates and station number
  training_data <- merge(
    merged_obs, training_data, by = c("station_number", "date")
  )

  # Calculate sine-transformed doy
  training_data <- dplyr::mutate(
    training_data, doy = sin((lubridate::yday(date) * 2 * pi) / 365)
  )

  # Drop unnecessary columns, might vary based on your data
  training_data <- training_data[, -c(1, 2, 4, 5, 6, 7, 8, 9, 10)] 

  # Convert swe_era5 to integer
  training_data$swe_era5 <- as.integer(training_data$swe_era5)

  # Rename columns
  colnames(training_data) <- c(
    "swe", "swe_era5", "elevation", "aspect", "roughness", "slope", "DOY"
  )

  # Save training dataset
  saveRDS(
    training_data, file = file.path(
      "output", simulation_name, paste0(
        "RF_SWE_training_data_", simulation_name, ".RData"
      )
    )
  )
}

# Function to train Random Forest models
train_rfr <- function() {
  # Load training data
  training_data <- readRDS(
    paste0("output/", simulation_name, "/RF_SWE_training_data_", simulation_name, ".RData")
  )

  # Remove 80% of rows in training_data where swe or swe_era5 is 0
  # This reduces training dataset size, improves model performance
  zero_rows <- which(training_data$swe == 0 | training_data$swe_era5 == 0)
  zero_rows_sample <- sample(zero_rows, size = floor(0.8 * length(zero_rows)))
  training_data <- training_data[-zero_rows_sample, ]

  # Create training data partition (80% training, 20% testing subset)
  training_data_partition <- caret::createDataPartition(
    y = training_data$swe, p = 0.8, list = FALSE
  )
  training_subset <- training_data[training_data_partition, ]
  testing_subset <- training_data[-training_data_partition, ]

  # Train Random Forest model using training subset
  rf_model <- randomForest::randomForest(
    swe ~ ., data = training_subset, ntree = 500, importance = TRUE
  )

  # Perform prediction on testing subset for internal validation
  predictions <- predict(rf_model, testing_subset)
  rmse <- sqrt(mean((testing_subset$swe - predictions)^2))
  rsq <- cor(testing_subset$swe, predictions)^2

  # Write internal validation summary
  writeLines(
    c(
      paste("RMSE:", rmse),
      paste("R-squared:", rsq)
    ),
    file.path("output/", simulation_name, "model_performance.txt")
  )

  # Plot and export variable importance plot
  png(file.path("output/", simulation_name, "variable_importance.png"))
  randomForest::varImpPlot(rf_model)
  dev.off()

  # Save trained model
  save(
    rf_model, file = file.path(
      "output", simulation_name, 
      paste0("RF_SWE_model_", simulation_name, ".RData")
    )
  )
}

# Function to predict downscaled SWE
predict_swe <- function(start_date, end_date) {
  # Load trained model
  load(
    file.path("output", simulation_name, 
              paste0("RF_SWE_model_", simulation_name, ".RData"))
  )

  # Loop through dates and generate predictions
  for (prediction_date in seq(
    from = as.Date(start_date), to = as.Date(end_date), by = "day"
  )) {

    # Get ERA5-SWE of prediction date
    era5_day <- subset(
      era5_full, time(era5_full) == prediction_date
    )

    # Calculate sine-transformed doy for prediction date
    doy_value <- sin((lubridate::yday(as.Date(prediction_date, tz = "UTC")) * 2 * pi) / 365)
    doy_day <- era5_day
    doy_day[doy_day > -1] <- doy_value

    # Generate prediction stack for prediction date and set names
    prediction_stack <- c(
      elevation, aspect, roughness, slope, era5_day, doy_day
    )
    names(prediction_stack) <- c(
      "elevation", "aspect", "roughness", "slope", "swe_era5", "DOY"
    )

    # Perform prediction and write result to output
    predicted_swe_day <- predict(prediction_stack, rf_model) # nolint
    terra::writeRaster(
      predicted_swe_day, file.path(
        "output", simulation_name, "prediction", paste0(
          "predicted_swe_", format(as.Date(prediction_date), "%Y-%m-%d"), ".tif"
        )
      ), overwrite = TRUE
    )
    print(
      paste(
        "Downscaled SWE predicted for:",
        format(as.Date(prediction_date), "%Y-%m-%d")
      )
    )
  }
}

# Execute based on user flags
if (create_new_dataset) {
  create_dataset()
}

if (train_new_model) {
  train_rfr()
}

if (do_predictions) {
  predict_swe(start_date, end_date)
}
