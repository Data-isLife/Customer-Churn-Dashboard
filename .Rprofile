# Keep local package installs inside this project and out of the GitHub upload.
local_library <- file.path(getwd(), ".Rlib")
if (dir.exists(local_library)) {
  .libPaths(c(normalizePath(local_library, winslash = "/"), .libPaths()))
}
