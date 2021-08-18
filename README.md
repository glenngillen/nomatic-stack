# Terraform AWS Hashistack

<a href="https://lab.gln.io/deploy?repo=glenngillen/nomatic-stack"><img src="https://lab.gln.io/terraform.deploy.svg?1" height="45" width="129"/></a>

This is a terraform module for setting up a Hashistack on AWS.

The HashiStack consists of Consul, Vault, and Nomad on infrastructure
launched by Terraform.

After a short initial setup a user is able to deploy
containerized applications to a Nomad cluster.

# Dependencies

* AWS Account (and an access key & secret key you can use)
* Terraform Cloud account (and org token & user token for the deploy button)
* Consul & Nomad installed locally (`brew install consul && brew install nomad`)
### Usage

* Click the deploy button above and follow the steps
* Approve the plan and apply the changes
* Once complete, go to the outputs tab on your workspace. Use the appropriate values in the following command on you local machine

```bash
export NOMAD_ADDR=workspace_output_nomad_server_url_here CONSUL_HTTP_ADDR=workspace_output_consul_server_url_here
```

```bash
consul acl bootstrap
export CONSUL_HTTP_TOKEN=output_of_SecretID_value_goes_here
```

```bash
nomad acl bootstrap
export NOMAD_TOKEN=output_of_SecretID_value_goes_here
```
