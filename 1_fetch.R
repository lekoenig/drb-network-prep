source("1_fetch/src/get_gf.R")
source("1_fetch/src/get_nhdplusv2.R")

p1_targets_list <- list(
  
  # Download PRMS reaches for the DRB
  tar_target(
    p1_GFv1_reaches_shp_zip,
    # Downloaded this manually from ScienceBase: 
    # https://www.sciencebase.gov/catalog/item/5f6a285d82ce38aaa244912e
    # Because it's a shapefile, it's not easily downloaded using sbtools
    # like other files are (see https://github.com/USGS-R/sbtools/issues/277).
    # Because of that and since it's small (<700 Kb) I figured it'd be fine to
    # just include in the repo and have it loosely referenced to the sb item ^
    "1_fetch/in/study_stream_reaches.zip",
    format = "file"
  ),

  # Unzip folder containing PRMS reaches shapefile
  tar_target(
    p1_GFv1_reaches_shp,
    unzip(p1_GFv1_reaches_shp_zip, exdir = "1_fetch/out/study_stream_reaches"),
    format = "file"
  ),
  
  # Read PRMS reaches shapefile in as an sf object
  tar_target(
    p1_GFv1_reaches_sf,
    sf::st_read(dsn = unique(dirname(p1_GFv1_reaches_shp)), layer = "study_stream_reaches", quiet=TRUE)
  ),
  
  # Download PRMS catchments from ScienceBase: 
  # https://www.sciencebase.gov/catalog/item/5362b683e4b0c409c6289bf6
  tar_target(
    p1_GFv1_catchments_shp,
    get_gf(out_dir = "1_fetch/out/", sb_id = '5362b683e4b0c409c6289bf6', sb_name = gf_data_select),
    format = "file"
  ),
  
  # Read PRMS catchment shapefile into sf object and filter to DRB
  # For national-scale data, layer_name is "nhruNationalIdentifier"
  # For regional-scale data, layer_name is "nhru"
  tar_target(
    p1_GFv1_catchments_sf,
    {
      # Read in layer containing hru's. Since the name of the layer depends on regional vs.
      # national-scale data, test that hru_layer_name is within set of expected options
      # before proceeding
      hru_layer_name <- grep("hru", sf::st_layers(p1_GFv1_catchments_shp)$name, value=TRUE)
      if(!hru_layer_name %in% c("nhru","nhruNationalIdentifier"))
        stop("Error: hru_layer_name differs from expected values. Check catchments shapefile.")
      # Read in catchment shapefile
      sf::st_read(dsn = p1_GFv1_catchments_shp, layer = hru_layer_name, quiet=TRUE) %>%
        # subset polygons within the DRB; region must be specified for national GF
        filter(hru_segment %in% p1_GFv1_reaches_sf$subsegseg, region == "02") %>%
        # fix geometry issues by defining a zero-width buffer around the polygon boundaries
        sf::st_buffer(.,0) %>%
        # format columns
        select(any_of(gf_cols_select)) %>%
        rename_with(.,function(x) case_when(x == "hru_id" ~ "hru_id_reg", TRUE ~ as.character(x)))
    }
  ),
  
  # Download NHDPlusV2 flowlines for the DRB
  tar_target(
    p1_nhdv2reaches_sf,
    get_nhdv2_flowlines(drb_huc8s)
  ),
  
  # Download NHDPlusv2 catchments for the DRB
  tar_target(
    p1_nhdv2_catchments_sf,
    {
      comids <- p1_nhdv2reaches_sf %>%
        filter(AREASQKM > 0) %>%
        pull(COMID)
      get_nhdplusv2_catchments(comids)
    }
  ),
  
  # Save NHDPlusv2 catchments as a geopackage
  tar_target(
    p1_nhdv2_catchments_gpkg,
    write_sf(p1_nhdv2_catchments_sf,
             dsn = "1_fetch/out/NHDPlusv2_catchments.gpkg", 
             layer = "NHDPlusv2_catchments", 
             driver = "gpkg",
             quiet = TRUE,
             # overwrite layer if already exists
             append = FALSE),
    format = "file"
  )
  
)

  