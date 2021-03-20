provider "oci" {
  tenancy_ocid     = var.tenancy-ocid
  user_ocid        = var.user-ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private-key-path
  region           = var.region
}

provider "cloudflare" {
  api_token = var.cf-token
}

data "cloudflare_zones" "itguy_pro" {
  filter {
    name = "itguy.pro"
  }
}

resource "oci_core_vcn" "big10" {
  cidr_block     = "10.19.0.0/16"
  compartment_id = var.tenancy-ocid
  display_name   = "big10"
  dns_label      = "big10"
}

resource "oci_core_internet_gateway" "big10-default" {
  compartment_id = var.tenancy-ocid
  display_name   = "big10-default"
  vcn_id         = oci_core_vcn.big10.id
}

resource "oci_core_security_list" "wg-default" {
  compartment_id = var.tenancy-ocid
  vcn_id         = oci_core_vcn.big10.id
  display_name   = "wg-default"

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "22"
      min = "22"
    }
  }

  ingress_security_rules {
    protocol = "17"
    source   = "0.0.0.0/0"

    udp_options {
      max = "51820"
      min = "51820"
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "53"
      min = "53"
    }
  }

  ingress_security_rules {
    protocol = "17"
    source   = "0.0.0.0/0"

    udp_options {
      max = "53"
      min = "53"
    }
  }

  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
  }
}

resource "oci_core_route_table" "wg-default" {
  compartment_id = var.tenancy-ocid
  vcn_id         = oci_core_vcn.big10.id
  display_name   = "wg-default"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.big10-default.id
  }
}

resource "oci_core_subnet" "wg" {
  compartment_id    = var.tenancy-ocid
  vcn_id            = oci_core_vcn.big10.id
  security_list_ids = [oci_core_security_list.wg-default.id]
  dns_label         = "wg"
  cidr_block        = "10.10.10.0/24"
  route_table_id    = oci_core_route_table.wg-default.id
  display_name      = "wg"
}

resource "oci_core_subnet" "centos" {
  compartment_id    = var.tenancy-ocid
  vcn_id            = oci_core_vcn.big10.id
  security_list_ids = [oci_core_security_list.wg-default.id]
  dns_label         = "centos"
  cidr_block        = "10.10.11.0/24"
  route_table_id    = oci_core_route_table.wg-default.id
  display_name      = "centos"
}


resource "oci_core_instance" "wg" {
  compartment_id      = var.tenancy-ocid
  availability_domain = "MSVG:CA-TORONTO-1-AD-1"
  shape               = "VM.Standard.E2.1.Micro"
  display_name        = "wg"

  create_vnic_details {
    subnet_id        = oci_core_subnet.wg.id
    hostname_label   = "wg"
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = "ocid1.image.oc1.ca-toronto-1..."
  }

  metadata = {
    ssh_authorized_keys = "${file("~/.ssh/key.pub")}"
  }
}

resource "cloudflare_record" "wg" {
  zone_id = data.cloudflare_zones.itguy_pro.zones[0].id
  name    = "recordlol."
  value   = oci_core_instance.wg.public_ip
  type    = "A"
  proxied = false
}

resource "oci_core_instance" "centos" {
  compartment_id      = var.tenancy-ocid
  availability_domain = "MSVG:CA-TORONTO-1-AD-1"
  shape               = "VM.Standard.E2.1.Micro"
  display_name        = "centos"

  create_vnic_details {
    subnet_id        = oci_core_subnet.centos.id
    hostname_label   = "centos"
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = "ocid1.image.oc1.ca-toronto-1..."
  }

  metadata = {
    ssh_authorized_keys = "${file("~/.ssh/oci2.pub")}"
  }
}

resource "cloudflare_record" "centos" {
  zone_id = data.cloudflare_zones.itguy_pro.zones[0].id
  name    = "name2."
  value   = oci_core_instance.centos.public_ip
  type    = "A"
  proxied = false
}