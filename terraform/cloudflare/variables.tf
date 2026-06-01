variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}
variable "cloudflare_zone_id" {
  type    = string
  default = "5fa18274dc370ccb5b4494fbecef2814"
}
variable "cloudflare_account_id" {
  type    = string
  default = "c7f77378cf53b5436dacbc6a8e673cc4"
}
variable "cloudflare_tunnel_id" {
  type    = string
  default = "2ef09425-ed87-4c07-a0e4-ecca2041dcdf"
}
