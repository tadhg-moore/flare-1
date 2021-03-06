#' @importFrom ncdf4 nc_open ncvar_get nc_close
#' @importFrom LakeEnsemblR get_output
#' @importFrom rLakeAnalyzer get.offsets

get_ler_var_all <- function(model, working_dir, z_out, vars_depth, vars_no_depth, diagnostic_vars, ler_yaml){

  temp <- LakeEnsemblR::get_output(config_yaml = ler_yaml, model = model, vars = "temp", obs_depths = z_out)$temp
  salt <- LakeEnsemblR::get_output(config_yaml = ler_yaml, model = model, vars = "salt", obs_depths = z_out)$salt
  ice <- LakeEnsemblR::get_output(config_yaml = ler_yaml, model = model, vars = "ice_height")$ice_height
  deps <- rLakeAnalyzer::get.offsets(temp)
  # Subset to z_out
  idx <- which(z_out %in% deps) + 1
  temp <- temp[, c(1, idx)]
  salt <- salt[, c(1, idx)]

  final_time_step <- nrow(temp)

  # No varying water level in Simstrat
  heights_surf <- max(deps)
  heights <- deps
  # heights_out <- rep()

  temps <- unlist(temp[final_time_step, -1])
  salt <- unlist(salt[final_time_step, -1])

  if( model == "GLM") {

    glm_nc <- ncdf4::nc_open(file.path(working_dir, model, "output", "output.nc"))
    tallest_layer <- ncdf4::ncvar_get(glm_nc, "NS")
    final_time_step <- length(tallest_layer)
    tallest_layer <- tallest_layer[final_time_step] # Edited
    heights <- ncdf4::ncvar_get(glm_nc, "z")
    heights_surf <- heights[tallest_layer, final_time_step]
    heights <- heights[1:tallest_layer, final_time_step]
    # heights_out <- heights_surf - z_out

    snow <- ncdf4::ncvar_get(glm_nc, "hsnow")[final_time_step]
    ice_white <- ncdf4::ncvar_get(glm_nc, "hwice")[final_time_step]
    ice_blue <- ncdf4::ncvar_get(glm_nc, "hice")[final_time_step]
    avg_surf_temp <- ncdf4::ncvar_get(glm_nc, "avg_surf_temp")[final_time_step]

    # glm_temps <- ncdf4::ncvar_get(glm_nc, "temp")[1:tallest_layer, final_time_step]

    # output <- array(NA, dim=c(tallest_layer,length(vars_depth)))
    # for(v in 1:length(vars_depth)){
    #   var_modeled <- ncdf4::ncvar_get(glm_nc, vars_depth[v])[, final_time_step]
    #   output[,v] <- rev(var_modeled[1:tallest_layer])
    # }
    output <- array(NA, dim=c(length(temps), length(vars_depth)))
    for(v in 1:length(vars_depth)){
      output[,v] <- temps
    }

    output_no_depth <- NA

    if(length(diagnostic_vars) > 0){
      diagnostics_output <- array(NA,dim=c(length(z_out), length(diagnostic_vars)))
      for(v in 1:length(diagnostic_vars)){
        var_modeled <- ncdf4::ncvar_get(glm_nc, diagnostic_vars[v])[1:tallest_layer, final_time_step]
        var_modeled <- approx(heights, var_modeled, xout = z_out, rule = 2)$y
        diagnostics_output[,v] <- var_modeled
      }
    }else{
      diagnostics_output <- NA
    }

    mixing_vars <- ncdf4::ncvar_get(glm_nc, "restart_variables")

    # salt <- ncdf4::ncvar_get(glm_nc, "salt")[1:tallest_layer]

    depths_enkf = rev(heights_surf - heights)

    ncdf4::nc_close(glm_nc)


    restart_vars <- list(avg_surf_temp = avg_surf_temp,
                         mixing_vars = mixing_vars)
  }

  # GOTM ----
  if( model == "GOTM") {

    output <- array(NA, dim=c(length(temps), length(vars_depth)))
    for(v in 1:length(vars_depth)){
      output[,v] <- temps
    }

    output_no_depth <- NA

    if(length(diagnostic_vars) > 0){
      diagnostics_output <- array(NA,dim=c(tallest_layer, length(diagnostic_vars)))
      for(v in 1:length(diagnostic_vars)){
        var_modeled <- ncdf4::ncvar_get(nc, diagnostic_vars[v])[, final_time_step]
        diagnostics_output[,v] <- var_modeled[1:tallest_layer]
      }
    }else{
      diagnostics_output <- NULL
    }

    mixing_vars <- NA # ncdf4::ncvar_get(nc, "restart_variables")

    depths_enkf = heights

    nc <- ncdf4::nc_open(file.path(working_dir, model, "output", "output.nc"))
    snow <- 0
    ice_white <- ncdf4::ncvar_get(nc, "Hice")[final_time_step]
    ice_blue <- 0
    avg_surf_temp <- NA
    ncdf4::nc_close(nc)

    restart_vars <- NULL
  }

  # Simstrat ----
  if( model == "Simstrat") {

    snow <- read.delim(file.path(model, "output", "SnowH_out.dat"), sep = ",")[final_time_step, 2]
    ice_white <- read.delim(file.path(model, "output", "WhiteIceH_out.dat"), sep = ",")[final_time_step, 2]

    # Extract variables for restarting initial conditions
    U <- read.delim(file.path(model, "output", "U_out.dat"), sep = ",")[final_time_step, -1]
    deps2 <- colnames(U) %>%
      regmatches(., gregexpr("[[:digit:]]+\\.*[[:digit:]]*", .)) %>%
      unlist() %>%
      as.numeric()
    U <- approx(deps2, U, z_out, rule = 2)$y
    V <- read.delim(file.path(model, "output", "V_out.dat"), sep = ",")[final_time_step, -1] %>%
      approx(deps2, ., z_out, rule = 2) %>%
      .[[2]]
    k <- read.delim(file.path(model, "output", "k_out.dat"), sep = ",")[final_time_step, -1] %>%
      approx(deps2, ., z_out, rule = 2) %>%
      .[[2]]
    eps <- read.delim(file.path(model, "output", "eps_out.dat"), sep = ",")[final_time_step, -1] %>%
      approx(deps2, ., z_out, rule = 2) %>%
      .[[2]]
    # ice_black <- read.delim(file.path(model, "output", "BlackIceH_out.dat"), sep = ",")[final_time_step, 2]
    ice_blue <- 0
    avg_surf_temp <- NA



    output <- array(NA, dim=c(length(temps), length(vars_depth)))
    for(v in 1:length(vars_depth)){
      output[,v] <- temps
    }

    output_no_depth <- NA

    if(length(diagnostic_vars) > 0){
      diagnostics_output <- array(NA,dim=c(tallest_layer, length(diagnostic_vars)))
      for(v in 1:length(diagnostic_vars)){
        var_modeled <- ncdf4::ncvar_get(nc, diagnostic_vars[v])[, final_time_step]
        diagnostics_output[,v] <- var_modeled[1:tallest_layer]
      }
    }else{
      diagnostics_output <- NULL
    }

    mixing_vars <- NA # ncdf4::ncvar_get(nc, "restart_variables")

    # depths_enkf = heights

    restart_vars <- list(U = U,
                         V = V,
                         k = k,
                         eps = eps)
  }

  depths_enkf = z_out


  return(list(output = output,
              output_no_depth = output_no_depth,
              lake_depth = heights_surf,
              depths_enkf = depths_enkf,
              snow_wice_bice = c(snow, ice_white, ice_blue),
              restart_vars = restart_vars,
              salt = salt,
              diagnostics_output = diagnostics_output))
}
