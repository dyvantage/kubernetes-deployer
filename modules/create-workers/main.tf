resource "aws_instance" "k8worker" {
  count           = var.num_instances
  ami             = lookup(var.instance_metadata,"ami")
  instance_type   = lookup(var.instance_metadata,"instance_type")
  key_name        = lookup(var.instance_metadata,"key_name")
  vpc_security_group_ids = var.instance_security_groups
  subnet_id = var.target_subnet_id
  private_ip = "10.240.0.2${count.index}"

  tags = {
    "Name" = "worker-${count.index}",
    "Pod_CIDR" = "10.200.${count.index}.0/24"
  }

  # ssh credentials
  connection {
    type        = "ssh"
    user        = lookup(var.instance_metadata,"ami_os_user")
    private_key = file(lookup(var.instance_metadata,"ami_os_private_key"))
    host        = self.public_ip
  }

  # copy post-install script
  provisioner "file" {
    source      = "scripts/post-install.sh"
    destination = "/tmp/post-install.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/post-install.sh",
      "sudo /tmp/post-install.sh worker-${count.index} > /tmp/post-install.log 2>&1",
    ]
  }
}
