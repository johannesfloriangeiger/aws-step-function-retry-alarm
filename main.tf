terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

# Lambda

data "aws_iam_policy_document" "random-fail" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "random-fail" {
  assume_role_policy = data.aws_iam_policy_document.random-fail.json
}

data "archive_file" "lambda-placeholder" {
  type        = "zip"
  output_path = "${path.module}/lambda-placeholder.zip"

  source {
    content  = "exports.handler = async (event) => {};"
    filename = "index.js"
  }
}

resource "aws_lambda_function" "random-fail" {
  function_name = "random-fail"
  role          = aws_iam_role.random-fail.arn
  runtime       = "nodejs12.x"
  handler       = "index.handler"
  filename      = data.archive_file.lambda-placeholder.output_path

  lifecycle {
    ignore_changes = [filename]
  }
}

# State machine

data "aws_iam_policy_document" "state-machine" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "state-machine" {
  assume_role_policy = data.aws_iam_policy_document.state-machine.json
}

resource "aws_iam_role_policy_attachment" "execute-lambda" {
  role       = aws_iam_role.state-machine.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
}

resource "aws_sfn_state_machine" "state-machine" {
  definition = <<EOF
  {
    "Comment": "A description of my state machine",
    "StartAt": "Lambda Invoke",
    "States": {
      "Lambda Invoke": {
        "Type": "Task",
        "Resource": "arn:aws:states:::lambda:invoke",
        "OutputPath": "$.Payload",
        "Parameters": {
          "Payload.$": "$",
          "FunctionName": "${aws_lambda_function.random-fail.arn}:$LATEST"
        },
        "Retry": [
          {
            "ErrorEquals": [
              "States.ALL"
            ],
            "IntervalSeconds": 1,
            "MaxAttempts": 1,
            "BackoffRate": 1
          }
        ],
        "End": true
      }
    }
  }
  EOF
  name       = "random-fail"
  role_arn   = aws_iam_role.state-machine.arn
}

# Alarm

resource "aws_cloudwatch_metric_alarm" "execution-failed" {
  alarm_name          = "execution-failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = "1"

  metric_query {
    id          = "mq"
    return_data = true

    metric {
      namespace   = "AWS/States"
      metric_name = "ExecutionsFailed"
      period      = 60
      stat        = "SampleCount"
      unit        = "Count"

      dimensions = {
        StateMachineArn = aws_sfn_state_machine.state-machine.arn
      }
    }
  }
}