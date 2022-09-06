# AWS Step Function example

## Setup

```
PROFILE=...
aws configure --profile $PROFILE
```

## Install

### Terraform

```
AWS_SDK_LOAD_CONFIG=1 AWS_PROFILE=$PROFILE terraform init
AWS_SDK_LOAD_CONFIG=1 AWS_PROFILE=$PROFILE terraform apply
```

### Lambda

```
zip lambda.zip index.js \
    && aws --profile $PROFILE \
        lambda update-function-code \
        --function-name random-fail \
        --zip-file fileb://lambda.zip \
        --publish \
    && rm lambda.zip
```

## Test

Run the state machine a few times with different inputs, e.g.

```
{
    "threshold": 0.1
}
```

to let it fail most likely and check the CloudWatch alarm: Around a minute after the state machine failed a few times
the alarm should be marked as "In alarm".