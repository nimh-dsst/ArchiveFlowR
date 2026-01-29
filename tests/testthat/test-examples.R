test_that("LabArchives auth demo app is installed", {
  app_path <- system.file(
    "examples/labarchives-auth-demo/app.R",
    package = "ArchiveFlowR"
  )

  expect_true(file.exists(app_path))
})
