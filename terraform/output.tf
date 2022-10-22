# Output ec2 info to ansible inventory

resource "local_sensitive_file" "private_key" {
  content = tls_private_key.key.private_key_pem
  filename          = format("%s/%s", abspath(path.root), "../ansible/ssh-key.pem")
  file_permission   = "0600"
}
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}./ansible/inventory.tmpl", {
      ip          = aws_instance.web1.public_ip,
      ssh_keyfile = local_sensitive_file.private_key.filename
  })
  filename = "${path.module}./ansible/inventory.yaml"
}
