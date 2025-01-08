# <img src="https://github.com/mibrechb/SOSW_WP3/blob/main/imgs/sosw_logo.png" width="80"> SOS-Water - EOP6 Downscaling Snow Water Equivalent (SWE)

The Earth Observation Prototype 6 (EOP6) for downscaling Snow Water Equivalent (SWE) is a prototype script designed to refine coarse resolution ERA5-Land SWE data to a higher spatial resolution using a random forest regression machine learning implementation in R. The script contains functionality to build a random forest training dataset, train a random forest regression model, and to perform SWE downscaling predictions. The random forest algorithm can be trained using SWE observations, open-source climate reanalysis data, and a variety of geographical data layers. The approach was designed and tested for the Upper Danube River Basin, but it can be applied anywhere when local predictor datasets and SWE observations are available.

This repository is part of the Deliverable 3.2 of SOS-Water - Water Resources System Safe Operating Space in a Changing Climate and Society ([DOI:10.3030/101059264](https://cordis.europa.eu/project/id/101059264)). Other code contributions to D3.2 can be found at the [SOS-Water - WP3 Earth Observation repository](https://github.com/mibrechb/SOSW_WP3).

Check out the project website at [sos-water.eu](https://sos-water.eu) for more information on the project.


---


## How to use

This folder contains the necessary scripts to produce a random forest training dataset, random forest regression model, and to perform SWE downscaling predictions. Follow these steps to run the script:

1. **Set the working directory**:  
   Edit line 14 in the script:
   ```R
   setwd("/path/to/working/directory")
   ```

2. **Provide a unique simulation name**:  
   Specify the simulation name on line 20. This name will be used as a prefix for directories where all output data will be stored:
   ```R
   simulation_name <- "my_simulation"
   ```

3. **Provide a raster file or shapefile for the area of interest (AOI)**:  
   Define the AOI on line 23. Supported formats include GeoTIFF and ESRI Shapefile.

4. **Supply predictor rasters**:  
   Ensure that all predictor rasters meet the following criteria:
   - Projected to a common coordinate reference system (e.g., EPSG:4326 (WGS84) or UTM).
   - Resampled to a common spatial resolution.
   - Provided in a supported format (GeoTIFF/NetCDF).

   The required predictor rasters include:
   - ERA5-Land Snow Water Equivalent [mm]
   - Elevation [m]
   - Aspect [°]
   - Slope [°]
   - Surface Roughness [m]

5. **Prepare SWE observation data**:  
   Supply a vector file and CSV file of SWE observations on lines 38–43. Combined the data needs to included time series and locations of weather stations.
   Due to the nature of each dataset being different the script should be adapted so that you eventually end up with the following columns:
   - `date` (e.g., `YYYY-MM-DD`)
   - `SWE` value (numeric, in mm)
   - `coordinates` (latitude, longitude)

6. Specify missing value.
   In line 45 specify `na_value` to be filtered out of training dataset.
   ```R
   na_value <- -999
   ```
   
7. **Specify user flags**:  
   Configure the following flags on lines 58–60 to enable or disable specific functionalities:
   - Create a new training dataset (`TRUE/FALSE`)
   - Train a random forest regression model (`TRUE/FALSE`)
   - Perform SWE downscaling predictions (`TRUE/FALSE`)
   ```R
   create_new_dataset <- TRUE      # Flag to create a new dataset
   train_new_model <- TRUE         # Flag to train a new RF model
   do_predictions <- TRUE          # Flag to perform predictions
   ```
   
9. **Set the date range for predictions**:  
   Specify the desired date range for predictions on lines 63–64 using the format `YYYY-MM-DD`.
   ```R
   start_date <- "2001-01-01" 
   end_date <- "2001-12-31"
   ```

11. **Run the script**:
    At the bottom of the script, run the selection of functions. 
   - Use the `create_dataset` function to build a training dataset.
   - Use the `train_rfr` function to train a random forest regression model.
   - Use the `predict_swe` function to perform SWE downscaling predictions for the specified date range.

---


## Technical Notes

Detailed technical notes on the algorithms used are available at the [SOS-Water - WP3 Earth Observation repository](https://github.com/mibrechb/SOSW_WP3). The produced training dataset, random forest regression model, and downscaled SWE dataset for the Upper Danube River Basin (1990–2023) can be requested from t.schults@futurewater.nl.


---


## Disclaimer

The views and opinions expressed are those of the author(s) only and do not necessarily reflect those of the European Union or CINEA. Neither the European Union nor the granting authority can be held responsible for them.


---


## Acknowledgment of Funding

<table style="border: none;">
  <tr>
    <td><img src="https://github.com/mibrechb/SOSW_WP3/blob/main/imgs/eucom_logo.png" alt="EU Logo" width="100"/></td>
    <td>This project has received funding from the European Union’s Horizon Europe research and innovation programme under grant agreement No 101059264.</td>
  </tr>
</table>
