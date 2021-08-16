# Terraform Exercise

## Commands

* `terraform init`

Initialize terraform project. Ideally should be used after defining the providers in your terraform project.
It fetches everything needed to interact with whatever provider was provided in your `.tf` files.

* `terraform plan`

Outputs the changes that terraform wants to make w/o applying them. This helps you check to be ensure you don't
break things in an actual production environment.

* `terraform apply`

Apply the changes described in the `terraform plan` command.

* `terraform destroy`

Delete / destroy all the changes made by `terraform`. It'll destroy every single resource created by `terraform`.


------------------------------

Use the `-target` flag to target a particular resource

```sh
terraform apply -target aws_instance.web_server
```