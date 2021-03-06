#' Title
#'
#' @param inflow_file_dir
#' @param inflow_obs
#' @param working_directory
#' @param config
#' @param state_names
#'
#' @return
#' @export
#'
#' @examples
create_ler_inflow_outflow_files <- function(inflow_file_dir,
                                            inflow_obs,
                                            working_directory,
                                            config,
                                            state_names)

{

  start_datetime <- lubridate::as_datetime(config$run_config$start_datetime)
  if(is.na(config$run_config$forecast_start_datetime)){
    end_datetime <- lubridate::as_datetime(config$run_config$end_datetime)
    forecast_start_datetime <- end_datetime
  }else{
    forecast_start_datetime <- lubridate::as_datetime(config$run_config$forecast_start_datetime)
    end_datetime <- forecast_start_datetime + lubridate::days(config$run_config$forecast_horizon)
  }

  obs_inflow <- readr::read_csv(inflow_obs, col_types = readr::cols())
  hour_step <- lubridate::hour(config$run_config$start_datetime)

  if(config$inflow$use_forecasted_inflow) {
    obs_inflow <- obs_inflow %>%
      dplyr::filter(time >= lubridate::as_date(start_datetime) & time <= lubridate::as_date(forecast_start_datetime)) %>%
      dplyr::mutate(inflow_num = 1)
  } else {
    obs_inflow <- obs_inflow %>%
      dplyr::filter(time >= lubridate::as_date(start_datetime) & time <= lubridate::as_date(end_datetime)) %>%
      dplyr::mutate(inflow_num = 1)
  }

  obs_outflow <- obs_inflow %>%
    dplyr::select(time, FLOW) %>%
    dplyr::mutate(outflow_num = 1)


  all_files <- list.files(inflow_file_dir, full.names = TRUE)

  inflow_files <- all_files[stringr::str_detect(all_files,"INFLOW")]
  outflow_files <- all_files[stringr::str_detect(all_files,"OUTFLOW")]

  if(length(inflow_files) > 0){
    d <- readr::read_csv(inflow_files[1], col_types = readr::cols())
    num_inflows <- max(c(d$inflow_num,obs_inflow$inflow_num))
  }else{
    num_inflows <- max(obs_inflow$inflow_num)
  }

  inflow_file_names <- array(NA, dim = c(length(inflow_files), num_inflows))

  for(j in 1:num_inflows){

    if(length(inflow_files) == 0 | end_datetime == forecast_start_datetime){

      obs_inflow_tmp <- obs_inflow %>%
        dplyr::filter(inflow_num == j) %>%
        dplyr::select(c("time", "FLOW", "TEMP", "SALT"))

      inflow_file_name <- file.path(working_directory, paste0("inflow",j,".csv"))

      readr::write_csv(x = obs_inflow_tmp,
                       inflow_file_name,
                       quote_escape = "none")
      inflow_file_names[, j] <- inflow_file_name
    }else{

      for(i in 1:length(inflow_files)){
        d <- readr::read_csv(inflow_files[i], col_types = readr::cols()) %>%
          dplyr::filter(inflow_num == j) %>%
          dplyr::select(time, FLOW, TEMP, SALT) %>%
          dplyr::mutate_at(dplyr::vars(c("FLOW", "TEMP", "SALT")), list(~round(., 4)))

        obs_inflow_tmp <- obs_inflow %>%
          dplyr::filter(inflow_num == j,
                        time < forecast_start_datetime) %>%
          dplyr::select(c("time", "FLOW", "TEMP", "SALT"))


        inflow <- rbind(obs_inflow_tmp, d)
        inflow <- as.data.frame(inflow)
        # inflow[, 1] <- as.POSIXct(inflow[, 1], tz = tz) + lubridate::hours(hour_step)
        inflow[, 1] <- format(inflow[, 1], format="%Y-%m-%d %H:%M:%S")
        inflow[, 1] <- lubridate::with_tz(inflow[, 1]) + lubridate::hours(hour_step)
        inflow[, 1] <- format(inflow[, 1], format="%Y-%m-%d %H:%M:%S")
        colnames(inflow) <- c("datetime", "Flow_metersCubedPerSecond", "Water_Temperature_celsius", "Salinity_practicalSalinityUnits")

        inflow_file_name <- file.path(working_directory, paste0("inflow",j,"_ens",i,".csv"))

        inflow_file_names[i, j] <- inflow_file_name

        if(config$inflow$use_forecasted_inflow){
          readr::write_csv(x = inflow,
                           inflow_file_name,
                           quote_escape = "none")
        }else{
          obs_inflow_tmp <- as.data.frame(obs_inflow_tmp)
          obs_inflow_tmp[, 1] <- format(obs_inflow_tmp[, 1], format="%Y-%m-%d %H:%M:%S")
          colnames(obs_inflow_tmp) <- c("datetime", "Flow_metersCubedPerSecond", "Water_Temperature_celsius", "Salinity_practicalSalinityUnits")
          readr::write_csv(x = obs_inflow_tmp,
                           inflow_file_name,
                           quote_escape = "none")

        }
      }
    }
  }


  if(length(outflow_files) > 0){
    d <- readr::read_csv(outflow_files[1], col_types = readr::cols())
    num_outflows <- max(c(d$outflow_num,obs_outflow$outflow_num))
  }else{
    num_outflows <- max(obs_outflow$outflow_num)
  }


  outflow_file_names <- array(NA, dim = c(length(outflow_files),num_outflows))


  for(j in 1:num_outflows){

    if(length(inflow_files) == 0 | end_datetime == forecast_start_datetime){

      obs_outflow_tmp <- obs_outflow %>%
        dplyr::filter(outflow_num == j) %>%
        dplyr::select(c("time", "FLOW"))

      outflow_file_name <- file.path(working_directory, paste0("outflow",j,".csv"))

      readr::write_csv(x = obs_outflow_tmp,
                       outflow_file_name,
                       quote_escape = "none")
      outflow_file_names[, j] <- outflow_file_name
    }else{

      for(i in 1:length(outflow_files)){
        d <- readr::read_csv(outflow_files[i], col_types = readr::cols())%>%
          dplyr::filter(outflow_num == j) %>%
          dplyr::select(time, FLOW) %>%
          dplyr::mutate_at(dplyr::vars(c("FLOW")), list(~round(., 4)))

        obs_outflow_tmp <- obs_outflow %>%
          dplyr::filter(outflow_num == j,
                        time < lubridate::as_date(forecast_start_datetime)) %>%
          dplyr::select(-outflow_num)

        outflow <- rbind(obs_outflow_tmp, d)
        outflow <- as.data.frame(outflow)
        outflow[, 1] <- format(outflow[, 1], format="%Y-%m-%d %H:%M:%S")
        colnames(outflow) <- c("datetime", "Flow_metersCubedPerSecond")

        outflow_file_name <- file.path(working_directory, paste0("outflow",j,"_ens",i,".csv"))

        outflow_file_names[i, j]  <- outflow_file_name

        if(config$inflow$use_forecasted_inflow){
          readr::write_csv(x = outflow,
                           outflow_file_name,
                           quote_escape = "none")
        }else{
          readr::write_csv(x = obs_outflow_tmp,
                           outflow_file_name,
                           quote_escape = "none")
        }
      }
    }
  }

  return(list(inflow_file_names = as.character(gsub("\\\\", "/", inflow_file_names)),
              outflow_file_names = as.character(gsub("\\\\", "/", outflow_file_names))))
}
