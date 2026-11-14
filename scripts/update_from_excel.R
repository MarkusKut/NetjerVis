# Local-only Excel/CSV/SVG synchronization for the Quarto publication.
# In environments without the external workbook, preserve bundled CSVs and SVGs.
if (!file.exists('R/data_config.R')) stop('Run from the Quarto project root')
settings <- new.env(parent=baseenv())
sys.source('R/data_config.R',envir=settings)
workbook <- settings$excel_workbook
required <- file.path('data',c('figures.csv','objects.csv','texts.csv',
  'measurements.csv','layouts.csv','drawings_manifest.csv','drawings_web.csv'))
if (!file.exists(workbook)) {
  missing <- required[!file.exists(required)]
  if(length(missing)) stop('External Excel workbook unavailable and prepared data missing: ',
    paste(missing,collapse=', '))
  message('External Excel workbook not available; using bundled publication data and drawings.')
} else {
  extra <- if(dir.exists('source/other-groups')) {
    list.files('source/other-groups',pattern='\\.csv$',full.names=TRUE,recursive=TRUE)
  } else character()
  inputs <- c(workbook,extra,'R/data_config.R','scripts/prepare_data.R')
  outputs <- file.path('data',c('figures.csv','objects.csv','texts.csv',
    'measurements.csv','layouts.csv','drawings_manifest.csv'))
  force <- isTRUE(getOption('catalog.force_refresh')) ||
    '--force' %in% commandArgs(trailingOnly=TRUE)
  needs_update <- force || !all(file.exists(outputs)) ||
    max(file.info(inputs)$mtime,na.rm=TRUE) >
    min(file.info(outputs)$mtime,na.rm=TRUE)
  if(needs_update){
    message('Reimporting Excel: ',workbook)
    sys.source('scripts/prepare_data.R',envir=new.env(parent=globalenv()))
  } else message('Excel unchanged; using prepared data.')
  # Run only on the local workstation, where ../../bilder/ paths are accessible.
  source('scripts/sync_drawings.R',local=TRUE)
}
