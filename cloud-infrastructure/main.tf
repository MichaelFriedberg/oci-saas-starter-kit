data "hcp_vault_secrets_app" "test" {
  app_name = "test"
}

data "oci_core_images" "oke_node_image" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.A1.Flex"
}

provider "oci" {
  alias            = "targetregion"
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key      = base64decode(data.hcp_vault_secrets_app.test.secrets["private_key"])
  region           = "us-ashburn-1"
}

resource "oci_core_vcn" "generated_oci_core_vcn" {
  cidr_block = "10.0.0.0/16"
  compartment_id = var.compartment_ocid
  display_name = "oke-vcn-quick-SaaS_Starter_Kit-55dfd4547"
  dns_label = "SaaSStarterKit"
}

resource "oci_core_internet_gateway" "generated_oci_core_internet_gateway" {
  compartment_id = var.compartment_ocid
  display_name = "oke-igw-quick-SaaS_Starter_Kit-55dfd4547"
  enabled = "true"
  vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_nat_gateway" "generated_oci_core_nat_gateway" {
  compartment_id = var.compartment_ocid
  display_name = "oke-ngw-quick-SaaS_Starter_Kit-55dfd4547"
  vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

############################################
# Data Source: All OCI Services
############################################
variable "use_existing_vcn" {
  default = true
}
data "oci_core_services" "AllOCIServices" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}
############################################
# Service Gateway
############################################
resource "oci_core_service_gateway" "generated_oci_core_service_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "oke-sgw-quick-SaaS_Starter_Kit-55dfd4547"

  services {
    service_id = lookup(data.oci_core_services.AllOCIServices.services[0], "id")
  }

  vcn_id = oci_core_vcn.generated_oci_core_vcn.id
}

resource "oci_core_route_table" "generated_oci_core_route_table" {
  compartment_id = var.compartment_ocid
  display_name = "oke-private-routetable-SaaS_Starter_Kit-55dfd4547"
  route_rules {
    description = "traffic to the internet"
    destination = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    network_entity_id = "${oci_core_nat_gateway.generated_oci_core_nat_gateway.id}"
  }
  route_rules {
    description = "traffic to OCI services"
    destination = "all-iad-services-in-oracle-services-network"
    destination_type = "SERVICE_CIDR_BLOCK"
    network_entity_id = "${oci_core_service_gateway.generated_oci_core_service_gateway.id}"
  }
  vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_subnet" "service_lb_subnet" {
  cidr_block = "10.0.20.0/24"
  compartment_id = var.compartment_ocid
  display_name = "oke-svclbsubnet-quick-SaaS_Starter_Kit-55dfd4547-regional"
  dns_label = "lbsuba1371119f"
  prohibit_public_ip_on_vnic = "false"
  route_table_id = "${oci_core_default_route_table.generated_oci_core_default_route_table.id}"
  security_list_ids = ["${oci_core_vcn.generated_oci_core_vcn.default_security_list_id}"]
  vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_subnet" "node_subnet" {
  cidr_block = "10.0.10.0/24"
  compartment_id = var.compartment_ocid
  display_name = "oke-nodesubnet-quick-SaaS_Starter_Kit-55dfd4547-regional"
  dns_label = "subf00e6c01c"
  prohibit_public_ip_on_vnic = "true"
  route_table_id = "${oci_core_route_table.generated_oci_core_route_table.id}"
  security_list_ids = ["${oci_core_security_list.node_sec_list.id}"]
  vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_subnet" "kubernetes_api_endpoint_subnet" {
  cidr_block = "10.0.0.0/28"
  compartment_id = var.compartment_ocid
  display_name = "oke-k8sApiEndpoint-subnet-quick-SaaS_Starter_Kit-55dfd4547-regional"
  dns_label = "subfd726ab95"
  prohibit_public_ip_on_vnic = "false"
  route_table_id = "${oci_core_default_route_table.generated_oci_core_default_route_table.id}"
  security_list_ids = ["${oci_core_security_list.kubernetes_api_endpoint_sec_list.id}"]
  vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_default_route_table" "generated_oci_core_default_route_table" {
  display_name = "oke-public-routetable-SaaS_Starter_Kit-55dfd4547"
  route_rules {
    description = "traffic to/from internet"
    destination = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    network_entity_id = "${oci_core_internet_gateway.generated_oci_core_internet_gateway.id}"
  }
  manage_default_resource_id = "${oci_core_vcn.generated_oci_core_vcn.default_route_table_id}"
}

resource "oci_core_security_list" "service_lb_sec_list" {
  compartment_id = var.compartment_ocid
  display_name = "oke-svclbseclist-quick-SaaS_Starter_Kit-55dfd4547"
  vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_security_list" "node_sec_list" {
  compartment_id = var.compartment_ocid
  display_name = "oke-nodeseclist-quick-SaaS_Starter_Kit-55dfd4547"
  egress_security_rules {
    description = "Allow pods on one worker node to communicate with pods on other worker nodes"
    destination = "10.0.10.0/24"
    destination_type = "CIDR_BLOCK"
    protocol = "all"
    stateless = "false"
  }
  egress_security_rules {
    description = "Access to Kubernetes API Endpoint"
    destination = "10.0.0.0/28"
    destination_type = "CIDR_BLOCK"
    protocol = "6"
    stateless = "false"
  }
  egress_security_rules {
    description = "Kubernetes worker to control plane communication"
    destination = "10.0.0.0/28"
    destination_type = "CIDR_BLOCK"
    protocol = "6"
    stateless = "false"
  }
  egress_security_rules {
    description = "Path discovery"
    destination = "10.0.0.0/28"
    destination_type = "CIDR_BLOCK"
    icmp_options {
      code = "4"
      type = "3"
    }
    protocol = "1"
    stateless = "false"
  }
  egress_security_rules {
    description = "Allow nodes to communicate with OKE to ensure correct start-up and continued functioning"
    destination = "all-iad-services-in-oracle-services-network"
    destination_type = "SERVICE_CIDR_BLOCK"
    protocol = "6"
    stateless = "false"
  }
  egress_security_rules {
    description = "ICMP Access from Kubernetes Control Plane"
    destination = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    icmp_options {
      code = "4"
      type = "3"
    }
    protocol = "1"
    stateless = "false"
  }
  egress_security_rules {
    description = "Worker Nodes access to Internet"
    destination = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol = "all"
    stateless = "false"
  }
  ingress_security_rules {
    description = "Allow pods on one worker node to communicate with pods on other worker nodes"
    protocol = "all"
    source = "10.0.10.0/24"
    stateless = "false"
  }
  ingress_security_rules {
    description = "Path discovery"
    icmp_options {
      code = "4"
      type = "3"
    }
    protocol = "1"
    source = "10.0.0.0/28"
    stateless = "false"
  }
  ingress_security_rules {
    description = "TCP access from Kubernetes Control Plane"
    protocol = "6"
    source = "10.0.0.0/28"
    stateless = "false"
  }
  ingress_security_rules {
    description = "Inbound SSH traffic to worker nodes"
    protocol = "6"
    source = "0.0.0.0/0"
    stateless = "false"
  }
  vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_security_list" "kubernetes_api_endpoint_sec_list" {
  compartment_id = var.compartment_ocid
  display_name = "oke-k8sApiEndpoint-quick-SaaS_Starter_Kit-55dfd4547"
  egress_security_rules {
    description = "Allow Kubernetes Control Plane to communicate with OKE"
    destination = "all-iad-services-in-oracle-services-network"
    destination_type = "SERVICE_CIDR_BLOCK"
    protocol = "6"
    stateless = "false"
  }
  egress_security_rules {
    description = "All traffic to worker nodes"
    destination = "10.0.10.0/24"
    destination_type = "CIDR_BLOCK"
    protocol = "6"
    stateless = "false"
  }
  egress_security_rules {
    description = "Path discovery"
    destination = "10.0.10.0/24"
    destination_type = "CIDR_BLOCK"
    icmp_options {
      code = "4"
      type = "3"
    }
    protocol = "1"
    stateless = "false"
  }
  ingress_security_rules {
    description = "External access to Kubernetes API endpoint"
    protocol = "6"
    source = "0.0.0.0/0"
    stateless = "false"
  }
  ingress_security_rules {
    description = "Kubernetes worker to Kubernetes API endpoint communication"
    protocol = "6"
    source = "10.0.10.0/24"
    stateless = "false"
  }
  ingress_security_rules {
    description = "Kubernetes worker to control plane communication"
    protocol = "6"
    source = "10.0.10.0/24"
    stateless = "false"
  }
  ingress_security_rules {
    description = "Path discovery"
    icmp_options {
      code = "4"
      type = "3"
    }
    protocol = "1"
    source = "10.0.10.0/24"
    stateless = "false"
  }
  vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_containerengine_cluster" "generated_oci_containerengine_cluster" {
  cluster_pod_network_options {
    cni_type = "OCI_VCN_IP_NATIVE"
  }
  compartment_id = var.compartment_ocid
  endpoint_config {
    is_public_ip_enabled = "true"
    subnet_id = "${oci_core_subnet.kubernetes_api_endpoint_subnet.id}"
  }
  freeform_tags = {
    "OKEclusterName" = "SaaS_Starter_Kit"
  }
  kubernetes_version = "v1.31.1"
  name = "SaaS_Starter_Kit"
  options {
    admission_controller_options {
      is_pod_security_policy_enabled = "false"
    }
    persistent_volume_config {
      freeform_tags = {
        "OKEclusterName" = "SaaS_Starter_Kit"
      }
    }
    service_lb_config {
      freeform_tags = {
        "OKEclusterName" = "SaaS_Starter_Kit"
      }
    }
    service_lb_subnet_ids = ["${oci_core_subnet.service_lb_subnet.id}"]
  }
  type = "BASIC_CLUSTER"
  vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

resource "oci_containerengine_node_pool" "create_node_pool_details0" {
  compartment_id     = var.compartment_ocid
  cluster_id         = oci_containerengine_cluster.generated_oci_containerengine_cluster.id
  name               = "pool1"
  kubernetes_version = "v1.31.1"

  node_config_details {
    size = 2

    # (1) Use a dynamic block for "placement_configs"
    dynamic "placement_configs" {
      # for_each can be a map or an object:
      # We'll create a map from the index (i) to the actual AD object
      for_each = {
        for i, ad in data.oci_identity_availability_domains.ads.availability_domains :
        i => ad
        if i < 3
      }

      # (2) For each item, define how the content of "placement_configs" block looks
      content {
        availability_domain = placement_configs.value.name
        subnet_id           = "${oci_core_subnet.node_subnet.id}"
      }
    }

    # Optional: Node Pool Pod Network Option
    node_pool_pod_network_option_details {
      cni_type = "OCI_VCN_IP_NATIVE"
    }
  }

  # Node shape and shape config
  node_shape = "VM.Standard.A1.Flex"
  node_shape_config {
    ocpus         = 2
    memory_in_gbs = 6
  }

  # Source details
  node_source_details {
    source_type = "IMAGE"
    image_id    = data.oci_core_images.oke_node_image.images[0].id
  }

  node_eviction_node_pool_settings {
    eviction_grace_duration = "PT60M"
  }
}


#
#resource "oci_containerengine_node_pool" "create_node_pool_details0" {
#  cluster_id = "${oci_containerengine_cluster.generated_oci_containerengine_cluster.id}"
#  compartment_id = var.compartment_ocid
#  freeform_tags = {
#    "OKEnodePoolName" = "pool1"
#  }
#  initial_node_labels {
#    key = "name"
#    value = "SaaS_Starter_Kit"
#  }
#  kubernetes_version = "v1.31.1"
#  name = "pool1"
#  node_config_details {
#    freeform_tags = {
#      "OKEnodePoolName" = "pool1"
#    }
#    node_pool_pod_network_option_details {
#      cni_type = "OCI_VCN_IP_NATIVE"
#    }
#    placement_configs {
#      availability_domain = "tFVX:US-ASHBURN-AD-1"
#      subnet_id = "${oci_core_subnet.node_subnet.id}"
#    }
#    placement_configs {
#      availability_domain = "tFVX:US-ASHBURN-AD-2"
#      subnet_id = "${oci_core_subnet.node_subnet.id}"
#    }
#    placement_configs {
#      availability_domain = "tFVX:US-ASHBURN-AD-3"
#      subnet_id = "${oci_core_subnet.node_subnet.id}"
#    }
#    size = "2"
#  }
#  node_eviction_node_pool_settings {
#    eviction_grace_duration = "PT60M"
#  }
#  node_shape = "VM.Standard.A1.Flex"
#  node_shape_config {
#    memory_in_gbs = "6"
#    ocpus = "2"
#  }
#  node_source_details {
#    image_id    = data.oci_core_images.oke_node_image.images[0].id
#    source_type = "IMAGE"
#  }
#}


