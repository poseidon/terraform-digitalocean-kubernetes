locals {
  official_images   = []
  is_official_image = contains(local.official_images, var.os_image)
}

# Controller Instance DNS records
resource "digitalocean_record" "controllers" {
  count = var.controller_count

  # DNS zone where record should be created
  domain = var.dns_zone

  # DNS record (will be prepended to domain)
  name = var.cluster_name
  type = "A"
  ttl  = 300

  # IPv4 addresses of controllers
  value = digitalocean_droplet.controllers.*.ipv4_address[count.index]
}

# Discrete DNS records for each controller's private IPv4 for etcd usage
resource "digitalocean_record" "etcds" {
  count = var.controller_count

  # DNS zone where record should be created
  domain = var.dns_zone

  # DNS record (will be prepended to domain)
  name = "${var.cluster_name}-etcd${count.index}"
  type = "A"
  ttl  = 300

  # private IPv4 address for etcd
  value = digitalocean_droplet.controllers.*.ipv4_address_private[count.index]
}

# Controller droplet instances
resource "digitalocean_droplet" "controllers" {
  count = var.controller_count

  name   = "${var.cluster_name}-controller-${count.index}"
  region = var.region

  image = var.os_image
  size  = var.controller_type

  # network
  vpc_uuid           = digitalocean_vpc.network.id
  # TODO: Only official DigitalOcean images support IPv6
  ipv6 = false

  user_data = data.ct_config.controller-ignitions.*.rendered[count.index]
  ssh_keys  = var.ssh_fingerprints

  tags = [
    digitalocean_tag.controllers.id,
  ]

  lifecycle {
    ignore_changes = [user_data]
  }
}

# Tag to label controllers
resource "digitalocean_tag" "controllers" {
  name = "${var.cluster_name}-controller"
}

# Controller Ignition configs
data "ct_config" "controller-ignitions" {
  count    = var.controller_count
  content  = data.template_file.controller-configs.*.rendered[count.index]
  strict   = true
  snippets = var.controller_snippets
}

# Controller Container Linux configs
data "template_file" "controller-configs" {
  count = var.controller_count

  template = file("${path.module}/cl/controller.yaml")

  vars = {
    # Cannot use cyclic dependencies on controllers or their DNS records
    etcd_name   = "etcd${count.index}"
    etcd_domain = "${var.cluster_name}-etcd${count.index}.${var.dns_zone}"
    # etcd0=https://cluster-etcd0.example.com,etcd1=https://cluster-etcd1.example.com,...
    etcd_initial_cluster   = join(",", data.template_file.etcds.*.rendered)
    cluster_dns_service_ip = cidrhost(var.service_cidr, 10)
    cluster_domain_suffix  = var.cluster_domain_suffix
  }
}

data "template_file" "etcds" {
  count    = var.controller_count
  template = "etcd$${index}=https://$${cluster_name}-etcd$${index}.$${dns_zone}:2380"

  vars = {
    index        = count.index
    cluster_name = var.cluster_name
    dns_zone     = var.dns_zone
  }
}

