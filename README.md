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
  
# Setup

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

## Opening access

The following is definitely bad practice, but I'm (currently/generally) super lazy and just want to get a PoC working... so I'm
opening up wwaaaayyyy more access to this than is advisable. Copy my mistakes at your own risk:

```bash
consul intention create "*" "*"
consul acl token update -id 00000000-0000-0000-0000-000000000002 -policy-id 00000000-0000-0000-0000-000000000001
```

**note:** `00000000-0000-0000-0000-000000000002` is the ID of the anonymous token. If it's not deterministic for some reason you can get the actual value you need by running `consul acl token list`. `00000000-0000-0000-0000-000000000001` is the policy ID for management policy. Get the actual ID by running `consul acl policy list`.
# Usage

## Check Consul is up

You can list the members of your consul cluster with:

```bash
$ consul members
Node             Address             Status  Type    Build  Protocol  DC   Segment
ip-10-0-100-219  54.227.22.196:8301  alive   server  1.9.5  2         dc1  <all>
ip-10-0-100-20   54.165.62.66:8301   alive   client  1.9.5  2         dc1  <default>
```

## View the Nomad UI

```bash
$ nomad ui -authenticate
```

## List the Nomad members

```bash
$ nomad server members
Name                       Address        Port  Status  Leader  Protocol  Build  Datacenter  Region
ip-10-0-100-219.us-east-1  54.227.22.196  4648  alive   true    2         1.1.1  us-east-1   us-east-1
```

## Actually wiring it all together

Start by creating a Nomad job file:

```bash
$ nomad job init
```

You'll need to change the targeted datacenter from `dc1` to `us-east-1`. Then you can test out the example:

```bash
$ nomad job run example.nomad
```

See what services are running in Consul (the previous step should have just deployed a redis-cache service onto the cluster):

```bash
$ consul catalog services
consul
nomad
nomad-client
redis-cache
vault
```

Let's deploy a reverse proxy to make routing to our web apps easy. Save the following to a file named `traefik.nomad`:

```hcl
job "traefik" {
  region      = "global"
  datacenters = ["us-east-1"]
  type        = "service"

  group "traefik" {
    count = 1

    network {
      port "http" {
        static = 8080
      }

      port "api" {
        static = 8081
      }
    }

    service {
      name = "traefik"

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v2.2"
        network_mode = "host"

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
        ]
      }

      template {
        data = <<EOF
[entryPoints]
    [entryPoints.http]
    address = ":8080"
    [entryPoints.traefik]
    address = ":8081"

[api]
    dashboard = true
    insecure  = true

# Enable Consul Catalog configuration backend.
[providers.consulCatalog]
    prefix           = "traefik"
    exposedByDefault = false

    [providers.consulCatalog.endpoint]
      address = "127.0.0.1:8500"
      scheme  = "http"
EOF

        destination = "local/traefik.toml"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
```

Now add it as a service job to Nomad:

```bash
$ nomad job plan traefik.nomad
```

**note:** I got what looked like an error response about evaluation ID not found. I don't know why or what that means, it seems to have worked though.

Create a file called `hello-world.nomad` and add the following to it:

```hcl
job "demo-webapp" {
  datacenters = ["us-east-1"]

  group "demo" {
    count = 2

    network {
      port  "http"{
        to = -1
      }
    }

    service {
      name = "demo-webapp"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.http.rule=Path(`/myapp`)",
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "2s"
        timeout  = "2s"
      }
    }

    task "server" {
      env {
        PORT    = "${NOMAD_PORT_http}"
        NODE_IP = "${NOMAD_IP_http}"
      }

      driver = "docker"

      config {
        image = "hashicorp/demo-webapp-lb-guide"
        ports = ["http"]
      }
    }
  }
}
```

If your example job/redis-cache from earlier is still running you'll need to stop it to make sure you've enough memory available for this hello world app (we're running a very small instance/cluster): 

```bash
$ nomad job stop example
```

Add hello-world to Nomad:

```bash
$ nomad job run hello-world.nomad
```