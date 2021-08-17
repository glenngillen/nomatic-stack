blueprint "nomatic-stack" {
  description = "This is a terraform module for setting up a Hashistack on AWS.\n\nThe HashiStack consists of Consul, Vault, and Nomad on infrastructure launched by Terraform."
  website = "https://www.hashicorp.com/"
  repository = "https://github.com/glenngillen/nomatic-stack"
  logo = "https://glenngillen.com/logo.svg"

  inputs = [
    {name = "AWS_ACCESS_KEY_ID", label = "AWS Access Key"},
    {name = "AWS_SECRET_ACCESS_KEY", label = "AWS Secret Key", sensitive=true}    
    {name = "TF_KEY_NAME", label = "AWS Keypair Name"}
  ]
}