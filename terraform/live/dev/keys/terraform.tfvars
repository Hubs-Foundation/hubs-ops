terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git?ref=feature/terraform-ret//terraform/modules/keys"
  }

  include {
    path = "${find_in_parent_folders()}"
  }
}

ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDbuVkL13VNny2ZcAPxJ9bzmYrxEmRwZMGLJZoTbkSpVrYSEFhOzdLDbjKsPpf28IRbEfv/l0elppO5Hx1GR/4XhyBsyX2iqcxz7ms1xI54lA3ocOwDOTPB9aT6vZEdJunO1oxD1iZ1K9ULe2UgKTLXhTuh39U0YADIFx2/papzZfjJjrTtLW0I8MaInkIt48R0cWX7ppsqbYmSsz5uhB3CokK0duBCJ2aMSehXSDzDPeA/3TvPQNHn6Fp7Lxghd5eshQSWhvkJ4f6sn4IeWaCGwSMDerwO614ECglwB63HUzFtVC6PYjZmUdNxu5zgi4kAHz8w22yqKWse6uLQmrgV"

