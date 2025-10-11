module vpc-test

go 1.21

require (
	github.com/gruntwork-io/terratest v0.46.11
	github.com/stretchr/testify v1.8.4
	github.com/aws/aws-sdk-go v1.44.122
)

replace github.com/petclinic/terraform-test-common => ../../test/common