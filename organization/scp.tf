# =============================================================================
# 1. NAT GATEWAY
#
# NAT Gateway is intentionally prohibited until an architectural requirement
# justifies its recurring cost.
# =============================================================================

resource "aws_organizations_policy" "deny_nat_gateway" {
  name        = "DenyNatGateway"
  description = "Prevents NAT Gateway creation in sandbox accounts."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid      = "DenyNatGatewayCreation"
        Effect   = "Deny"
        Action   = "ec2:CreateNatGateway"
        Resource = "*"
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "deny_nat_gateway_sandbox" {
  policy_id = aws_organizations_policy.deny_nat_gateway.id
  target_id = aws_organizations_organizational_unit.sandbox.id
}


# =============================================================================
# 2. EC2
#
# Approved instance catalog:
#   - t3.micro
#
# Security:
#   - IMDSv2 required at launch.
#   - Existing instances cannot be changed back to IMDSv1.
# =============================================================================

resource "aws_organizations_policy" "restrict_ec2_instance_types" {
  name        = "RestrictEC2InstanceTypes"
  description = "Restricts EC2 instance types and requires IMDSv2 in sandbox accounts."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid      = "RestrictEC2InstanceTypes"
        Effect   = "Deny"
        Action   = "ec2:RunInstances"
        Resource = "arn:aws:ec2:*:*:instance/*"

        Condition = {
          StringNotEquals = {
            "ec2:InstanceType" = [
              "t3.micro"
            ]
          }
        }
      },

      {
        Sid      = "RequireIMDSv2"
        Effect   = "Deny"
        Action   = "ec2:RunInstances"
        Resource = "arn:aws:ec2:*:*:instance/*"

        Condition = {
          StringNotEquals = {
            "ec2:MetadataHttpTokens" = "required"
          }
        }
      },

      {
        Sid      = "DenyIMDSv1HttpTokensModification"
        Effect   = "Deny"
        Action   = "ec2:ModifyInstanceMetadataOptions"
        Resource = "arn:aws:ec2:*:*:instance/*"

        Condition = {
          StringNotEquals = {
            "ec2:Attribute/HttpTokens" = "required"
          }

          Null = {
            "ec2:Attribute/HttpTokens" = false
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "restrict_ec2_instance_types_sandbox" {
  policy_id = aws_organizations_policy.restrict_ec2_instance_types.id
  target_id = aws_organizations_organizational_unit.sandbox.id
}


# =============================================================================
# 3. RDS
#
# Approved baseline:
#   - PostgreSQL
#   - db.t4g.micro
#   - private
#   - encrypted
#   - maximum 30 GiB
#
# Aurora/clusters/read replicas/blue-green are prohibited until explicitly
# required by the architecture.
# =============================================================================

resource "aws_organizations_policy" "restrict_rds_instance_classes" {
  name        = "RestrictRDSInstanceClasses"
  description = "Restricts RDS configuration and scaling options in sandbox accounts."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "RestrictRDSInstanceClasses"
        Effect = "Deny"

        Action = [
          "rds:CreateDBInstance",
          "rds:ModifyDBInstance",
          "rds:RestoreDBInstanceFromDBSnapshot",
          "rds:RestoreDBInstanceToPointInTime",
          "rds:RestoreDBInstanceFromS3"
        ]

        Resource = "*"

        Condition = {
          StringNotEquals = {
            "rds:DatabaseClass" = [
              "db.t4g.micro"
            ]
          }
        }
      },

      {
        Sid    = "RestrictRDSEngine"
        Effect = "Deny"

        Action = [
          "rds:CreateDBInstance",
          "rds:RestoreDBInstanceFromDBSnapshot",
          "rds:RestoreDBInstanceToPointInTime",
          "rds:RestoreDBInstanceFromS3"
        ]

        Resource = "*"

        Condition = {
          StringNotEquals = {
            "rds:DatabaseEngine" = "postgres"
          }
        }
      },

      {
        Sid    = "DenyPublicRDS"
        Effect = "Deny"

        Action = [
          "rds:CreateDBInstance",
          "rds:ModifyDBInstance",
          "rds:RestoreDBInstanceFromDBSnapshot",
          "rds:RestoreDBInstanceToPointInTime",
          "rds:RestoreDBInstanceFromS3"
        ]

        Resource = "*"

        Condition = {
          Bool = {
            "rds:PubliclyAccessible" = "true"
          }
        }
      },

      {
        Sid    = "RequireRDSEncryption"
        Effect = "Deny"

        Action = [
          "rds:CreateDBInstance",
          "rds:RestoreDBInstanceFromDBSnapshot",
          "rds:RestoreDBInstanceToPointInTime",
          "rds:RestoreDBInstanceFromS3"
        ]

        Resource = "*"

        Condition = {
          Bool = {
            "rds:StorageEncrypted" = "false"
          }
        }
      },

      {
        Sid    = "RestrictRDSStorageSize"
        Effect = "Deny"

        Action = [
          "rds:CreateDBInstance",
          "rds:ModifyDBInstance",
          "rds:RestoreDBInstanceFromDBSnapshot",
          "rds:RestoreDBInstanceToPointInTime",
          "rds:RestoreDBInstanceFromS3"
        ]

        Resource = "*"

        Condition = {
          NumericGreaterThan = {
            "rds:StorageSize" = "30"
          }
        }
      },

      {
        Sid    = "DenyRDSScaleOutFeatures"
        Effect = "Deny"

        Action = [
          "rds:CreateDBCluster",
          "rds:CreateGlobalCluster",
          "rds:CreateDBInstanceReadReplica",
          "rds:CreateBlueGreenDeployment",
          "rds:RestoreDBClusterFromSnapshot",
          "rds:RestoreDBClusterToPointInTime"
        ]

        Resource = "*"
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "restrict_rds_instance_classes_sandbox" {
  policy_id = aws_organizations_policy.restrict_rds_instance_classes.id
  target_id = aws_organizations_organizational_unit.sandbox.id
}


# =============================================================================
# 4. REGION GUARDRAIL
#
# Regional workload:
#   - ap-northeast-1
#
# Global AWS services are excluded from the generic regional deny.
#
# ACM/WAF:
#   - ap-northeast-1
#   - us-east-1
#
# us-east-1 is required for CloudFront-related ACM/WAF resources, but this does
# NOT allow EC2/RDS workloads to run there.
# =============================================================================

resource "aws_organizations_policy" "region_guardrail" {
  name        = "RestrictRegions"
  description = "Restricts sandbox regional workloads to ap-northeast-1 with controlled global-service exceptions."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "DenyOutsideTokyo"
        Effect = "Deny"

        NotAction = [
          "account:*",
          "budgets:*",
          "cloudfront:*",
          "iam:*",
          "organizations:*",
          "route53:*",
          "sts:*",
          "support:*",

          # Controlled separately because CloudFront can require us-east-1.
          "acm:*",
          "wafv2:*"
        ]

        Resource = "*"

        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = [
              "ap-northeast-1"
            ]
          }
        }
      },

      {
        Sid      = "RestrictACMRegions"
        Effect   = "Deny"
        Action   = "acm:*"
        Resource = "*"

        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = [
              "ap-northeast-1",
              "us-east-1"
            ]
          }
        }
      },

      {
        Sid      = "RestrictWAFRegions"
        Effect   = "Deny"
        Action   = "wafv2:*"
        Resource = "*"

        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = [
              "ap-northeast-1",
              "us-east-1"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "region_guardrail_sandbox" {
  policy_id = aws_organizations_policy.region_guardrail.id
  target_id = aws_organizations_organizational_unit.sandbox.id
}


# =============================================================================
# 5. SANDBOX SECURITY + COST GUARDRAILS
# =============================================================================

resource "aws_organizations_policy" "sandbox_security_cost_guardrails" {
  name        = "SandboxSecurityCostGuardrails"
  description = "Security, persistence and cost guardrails for sandbox accounts."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"

    Statement = [

      # -----------------------------------------------------------------------
      # IAM persistence
      #
      # Human access:
      #   IAM Identity Center
      #
      # CI/CD:
      #   GitHub OIDC + STS
      #
      # Permanent IAM user credentials are not part of the platform.
      # -----------------------------------------------------------------------

      {
        Sid    = "DenyIAMUserPersistence"
        Effect = "Deny"

        Action = [
          "iam:CreateUser",
          "iam:CreateAccessKey",
          "iam:CreateLoginProfile",
          "iam:UpdateLoginProfile",
          "iam:CreateServiceSpecificCredential",
          "iam:ResetServiceSpecificCredential",
          "iam:UploadSigningCertificate",
          "iam:UploadSSHPublicKey"
        ]

        Resource = "*"
      },

      # -----------------------------------------------------------------------
      # Organization governance
      # -----------------------------------------------------------------------

      {
        Sid    = "DenyAccountDeparture"
        Effect = "Deny"

        Action = [
          "organizations:LeaveOrganization",
          "account:CloseAccount"
        ]

        Resource = "*"
      },

      # -----------------------------------------------------------------------
      # Service Quotas
      #
      # A compromised sandbox cannot increase its own resource quotas.
      # -----------------------------------------------------------------------

      {
        Sid    = "DenyQuotaIncreases"
        Effect = "Deny"

        Action = [
          "servicequotas:RequestServiceQuotaIncrease",
          "servicequotas:PutServiceQuotaIncreaseRequestIntoTemplate",
          "servicequotas:StartAutoManagement",
          "servicequotas:UpdateAutoManagement"
        ]

        Resource = "*"
      },

      # -----------------------------------------------------------------------
      # Purchases / subscriptions / financial commitments
      # -----------------------------------------------------------------------

      {
        Sid      = "DenyMarketplaceSubscriptions"
        Effect   = "Deny"
        Action   = "aws-marketplace:Subscribe"
        Resource = "*"
      },

      {
        Sid      = "DenyShieldAdvancedSubscription"
        Effect   = "Deny"
        Action   = "shield:CreateSubscription"
        Resource = "*"
      },

      {
        Sid    = "DenyLongTermCommitments"
        Effect = "Deny"

        Action = [
          "ec2:PurchaseReservedInstancesOffering",
          "rds:PurchaseReservedDBInstancesOffering",
          "savingsplans:CreateSavingsPlan"
        ]

        Resource = "*"
      },

      # -----------------------------------------------------------------------
      # Alternative / expensive EC2 capacity mechanisms
      #
      # CreateFleet is intentionally denied for now.
      # Karpenter will require this decision to be revisited later.
      # -----------------------------------------------------------------------

      {
        Sid    = "DenyUnapprovedEC2CapacityMechanisms"
        Effect = "Deny"

        Action = [
          "ec2:AllocateHosts",
          "ec2:CreateCapacityReservation",
          "ec2:CreateCapacityReservationFleet",
          "ec2:RequestSpotInstances",
          "ec2:RequestSpotFleet",
          "ec2:CreateFleet"
        ]

        Resource = "*"
      },

      # -----------------------------------------------------------------------
      # Network resources that are not part of the CloudContent architecture
      # -----------------------------------------------------------------------

      {
        Sid    = "DenyUnapprovedNetworkCostResources"
        Effect = "Deny"

        Action = [
          "ec2:AllocateAddress",
          "ec2:CreateTransitGateway",
          "ec2:CreateClientVpnEndpoint",
          "ec2:CreateVpnConnection"
        ]

        Resource = "*"
      },

      # -----------------------------------------------------------------------
      # High-cost EBS feature not required by CloudContent.
      # -----------------------------------------------------------------------

      {
        Sid      = "DenyEBSFastSnapshotRestore"
        Effect   = "Deny"
        Action   = "ec2:EnableFastSnapshotRestores"
        Resource = "*"
      },

      # -----------------------------------------------------------------------
      # EBS catalog
      #
      # Approved:
      #   type       = gp3
      #   max size   = 30 GiB
      #   max IOPS   = 3000
      #   throughput = 125 MiB/s
      #
      # RunInstances is included because instance launches can create EBS
      # volumes at the same time.
      # -----------------------------------------------------------------------

      {
        Sid    = "RestrictEBSVolumeType"
        Effect = "Deny"

        Action = [
          "ec2:CreateVolume",
          "ec2:ModifyVolume",
          "ec2:RunInstances"
        ]

        Resource = "arn:aws:ec2:*:*:volume/*"

        Condition = {
          StringNotEquals = {
            "ec2:VolumeType" = "gp3"
          }
        }
      },

      {
        Sid    = "RestrictEBSVolumeSize"
        Effect = "Deny"

        Action = [
          "ec2:CreateVolume",
          "ec2:ModifyVolume",
          "ec2:RunInstances"
        ]

        Resource = "arn:aws:ec2:*:*:volume/*"

        Condition = {
          NumericGreaterThan = {
            "ec2:VolumeSize" = "30"
          }
        }
      },

      {
        Sid    = "RestrictEBSVolumeIOPS"
        Effect = "Deny"

        Action = [
          "ec2:CreateVolume",
          "ec2:ModifyVolume",
          "ec2:RunInstances"
        ]

        Resource = "arn:aws:ec2:*:*:volume/*"

        Condition = {
          NumericGreaterThan = {
            "ec2:VolumeIops" = "3000"
          }
        }
      },

      {
        Sid    = "RestrictEBSVolumeThroughput"
        Effect = "Deny"

        Action = [
          "ec2:CreateVolume",
          "ec2:ModifyVolume",
          "ec2:RunInstances"
        ]

        Resource = "arn:aws:ec2:*:*:volume/*"

        Condition = {
          NumericGreaterThan = {
            "ec2:VolumeThroughput" = "125"
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "sandbox_security_cost_guardrails" {
  policy_id = aws_organizations_policy.sandbox_security_cost_guardrails.id
  target_id = aws_organizations_organizational_unit.sandbox.id
}