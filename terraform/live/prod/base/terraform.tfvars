terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/base"
  }

  include {
    path = "${find_in_parent_folders()}"
  }
}

ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDI+YCZx8dvtmcILtCkdr3yt2ngLUxIwuB8qyuvvINN3CSmKwfdbJDuCLspKy5/JxTqhIcrHGC4Jab8RpuA3i7ibmerMssMlinuZtwHgZo46h0df8q1Dw5juYH73jFOkqYGqDJP8OBbGpsnjHmW5rnKT8AdkA1AkVwhCCfQ1C3d0BMHnh3JVY61zaHnU0DwAWyy1gsdbtkX9+MNV/32ERZEr5x8N7np2cV+K3fjmfxzoWunoC0QK5TwrbrjEcH9slIrm4w4j0BgHZzyQnb5/6JEbzha7I7wd4r3mBtDhOALydWLuoTwQHUYO2E6p/FnlJOSKUSVMYsCCxN10+p+pyTj"

link_redirector_enabled = true
link_redirector_domains = ["hub.link", "hubs.link"]
link_redirector_target = "https://hubs.mozilla.com/link"
link_redirector_target_hostname = "hubs.mozilla.com"
