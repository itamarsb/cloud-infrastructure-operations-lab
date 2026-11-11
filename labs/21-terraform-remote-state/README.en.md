# Lab 21 — Terraform Remote State with Amazon S3 and Native Locking

[**Português (Brasil)**](README.md) · **English**

## Overview

Lab 21 demonstrates how to move a Terraform-managed object's state from the local filesystem to a private, encrypted, versioned Amazon S3 backend while preserving its identity and outputs. It also demonstrates **native S3 state locking** by deliberately attempting two concurrent operations against the same state.

The exercise separates the infrastructure that hosts the backend from the Terraform configuration that uses it:

- **Bootstrap configuration** (`bootstrap/`): Uses **local state throughout** to create and later remove six S3 backend-related AWS resources.
- **Exercise configuration** (`terraform/`): Manages one built-in `terraform_data.lab21` object, initially with local state and then with remote S3 state after migration.

This separation avoids storing the bootstrap's own state in the bucket it manages and later destroys.

**Original result:** Completed on October 4, 2026. The recorded execution provisioned and checked the backend, created the exercise object locally, migrated its state to S3 without changing the object's identity, demonstrated an actual locking conflict, destroyed the exercise, deleted 14 historical S3 versions/delete markers, destroyed six bootstrap resources, and independently confirmed that the bucket no longer existed.

**Review boundary:** This English documentation was prepared from committed source and original historical records. No Terraform command, AWS API mutation, state migration, or deletion was executed during this documentation review.

## Architecture

```text
Windows workstation — Terraform CLI 1.16.1
          |
          +-- bootstrap/  [LOCAL STATE]
          |       |
          |       +-- AWS provider + IAM Identity Center
          |       |
          |       +-- Amazon S3 state bucket
          |              +-- Block Public Access
          |              +-- BucketOwnerEnforced
          |              +-- Versioning
          |              +-- SSE-S3 (AES256)
          |              +-- Deny insecure transport
          |
          +-- terraform/  [EXERCISE STATE]
                  |
                  +-- Initially: local state
                  |       terraform_data.lab21
                  |
                  +-- After migration: S3 backend
                          |
                          +-- lab21/exercise/terraform.tfstate
                          +-- lab21/exercise/terraform.tfstate.tflock
```

The lab did **not** create EC2 instances, Nginx services, load balancers, databases, VPCs or EBS volumes. The AWS resources were S3 bucket configuration objects used to host the backend. The built-in `terraform_data` exercise object does not provision cloud infrastructure.

Remote state storage does **not** imply remote Terraform execution: the CLI continued running on the Windows workstation.

## Environment and dependency constraints

| Component | Recorded setup |
|---|---|
| Operating system | Windows 11 |
| Shell | Windows PowerShell 5.1 |
| Terraform CLI | `1.16.1` |
| Terraform constraint | `>= 1.16.1, < 1.17.0` |
| AWS provider used by bootstrap | `hashicorp/aws`, locked to `6.67.0` |
| AWS provider constraint | `~> 6.0` |
| AWS CLI | v2 |
| AWS authentication | IAM Identity Center |
| CLI profile | `cloud-operations-lab` |
| Region | `us-east-1` |
| Workspace | `default` |
| Bootstrap backend | Local |
| Exercise backend after migration | Amazon S3 with `use_lockfile = true` |

The supported Terraform range is deliberately narrow. A new run must use a compatible installed Terraform version; do not treat the historical version as proof that a different binary has been tested.

The bootstrap's committed `.terraform.lock.hcl` selects AWS provider `6.67.0` and stores package checksums. The dependency lock file is **not** the same as the runtime state-locking `.tflock` object.

## Repository structure

```text
labs/21-terraform-remote-state/
├── README.md
├── README.en.md
├── bootstrap/
│   ├── .terraform.lock.hcl
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── variables.tf
│   └── versions.tf
├── terraform/
│   ├── main.tf
│   ├── outputs.tf
│   └── versions.tf
├── scripts/
│   ├── test-aws-terraform-remote-state-prerequisites.ps1
│   └── test-aws-terraform-state-bucket.ps1
└── images/
    └── 23 historical screenshots
```

The workflow also creates `local-artifacts/` and local variable, backend-configuration, state, and plan files. They are intentionally not committed.

| File | Responsibility |
|---|---|
| [Bootstrap resources](bootstrap/main.tf) | Create the bucket and five bucket-level security/configuration resources |
| [Bootstrap provider](bootstrap/providers.tf) | Profile, Region, allowed AWS account, default tags |
| [Bootstrap variables](bootstrap/variables.tf) | Require a valid expected AWS account ID and other inputs |
| [Bootstrap outputs](bootstrap/outputs.tf) | Return bucket name, state key, lock key, and backend configuration |
| [Bootstrap version/backend](bootstrap/versions.tf) | Pin CLI compatibility and retain a local backend |
| [Provider dependency lock](bootstrap/.terraform.lock.hcl) | Record selected AWS provider and checksums |
| [Exercise object](terraform/main.tf) | Manage `terraform_data.lab21` |
| [Exercise outputs](terraform/outputs.tf) | Expose `resource_id` and `lab_summary` |
| [Exercise backend declaration](terraform/versions.tf) | Declare the S3 backend in the final committed configuration |
| [Prerequisites validator](scripts/test-aws-terraform-remote-state-prerequisites.ps1) | Check local environment, account, empty starting state and bucket-name conflict |
| [S3 bucket validator](scripts/test-aws-terraform-state-bucket.ps1) | Independently inspect bucket protections, identity and optional emptiness |

## Six bootstrap-managed AWS resources

| Terraform address | Purpose |
|---|---|
| `aws_s3_bucket.state` | Dedicated bucket; `force_destroy = false` |
| `aws_s3_bucket_public_access_block.state` | Four public-access blocks |
| `aws_s3_bucket_ownership_controls.state` | `BucketOwnerEnforced` |
| `aws_s3_bucket_versioning.state` | S3 object versioning |
| `aws_s3_bucket_server_side_encryption_configuration.state` | Default SSE-S3 / AES256 |
| `aws_s3_bucket_policy.state` | Deny insecure transport (`aws:SecureTransport = false`) |

The bucket's provider is restricted to an explicitly supplied allowed account, and the bucket has lab-specific tags. The configuration enforces the `default` workspace and checks the authenticated account before resource creation.

The source does **not** define general-purpose least-privilege IAM policies for every Terraform operator. The bucket's `DenyInsecureTransport` statement protects against insecure transport; it does **not** by itself restrict every authenticated principal to the least permissions needed.

**Versioning is not immutable retention.** It preserves historical object versions, but an authorized principal can permanently remove them, as demonstrated by this lab's cleanup.

### Backend object keys

| Element | Recorded convention |
|---|---|
| Bucket name | `lab21-terraform-state-<ACCOUNT_ID>-us-east-1` |
| Remote state | `lab21/exercise/terraform.tfstate` |
| Native lock object | `lab21/exercise/terraform.tfstate.tflock` |

The exercise backend configuration uses:

```hcl
backend "s3" {}
```

Its concrete values are supplied by a **local, untracked** `lab21.s3.tfbackend.json` file derived from verified bootstrap outputs. The recorded backend options include `bucket`, `key`, `region`, `profile`, `allowed_account_ids`, `encrypt = true`, and `use_lockfile = true`.

**Native locking:** This laboratory used S3 lock files, not a DynamoDB table. Do not describe it as DynamoDB-based locking.

## Critical reproduction note: the committed configuration is post-migration

The current committed [`terraform/versions.tf`](terraform/versions.tf) already declares `backend "s3" {}`. That is the **final configuration after the historical migration**, not the initial baseline configuration.

To reproduce the complete **local → S3 migration**, an operator must deliberately prepare the exercise's *initial local-backend configuration* in an isolated working copy before the baseline `init` and `apply`. After creating and preserving the local state, the operator changes the exercise's backend declaration to S3 and runs `init -migrate-state`.

Do not try to create a “local baseline” by running the committed S3 backend unchanged. After the original cleanup, the S3 bucket no longer exists; an initial `init` of the current exercise configuration will require a newly provisioned backend.

For a controlled rehearsal, preserve the original source in Git, use a clean dedicated checkout, and record each intentional backend change before proceeding.

## Original execution workflow

The following steps describe the workflow and useful command patterns. **They are not a one-shot executable deployment script**: bootstrap variable values and actual S3 state/bucket identifiers must come from a freshly authorized environment.

### 1. Check local environment and account identity

```powershell
aws sso login --profile cloud-operations-lab

aws sts get-caller-identity `
    --profile cloud-operations-lab `
    --region us-east-1

$LabPath = ".\labs\21-terraform-remote-state"
$BootstrapPath = (Resolve-Path "$LabPath\bootstrap").Path
$ExercisePath = (Resolve-Path "$LabPath\terraform").Path
```

Run the existing prerequisites script with the actual **authorized** AWS account ID:

```powershell
& "$LabPath\scripts\test-aws-terraform-remote-state-prerequisites.ps1" `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -ExpectedAccountId "<authorized 12-digit account ID>"
```

The script checks Git/Terraform/AWS CLI, the Terraform version range, uncommitted changes, local state/backend artifacts, existing workspace selections, the AWS account and expected absence of the Lab 21 bucket.

**Important:** The `-ExpectedAccountId` parameter must be a real twelve-digit value supplied by the authorized operator, **without angle brackets**. The placeholder above is instructional and must be replaced before execution.

The original prerequisites step did **not** mutate AWS resources. A passing result provides a starting-state check, not an authorization to remove unrelated objects.

### 2. Provision the S3 backend with separate local-state bootstrap

The bootstrap is initialized, format-checked, validated, and planned with the required `expected_account_id` variable and reviewed account/Region parameters.

```powershell
& terraform "-chdir=$BootstrapPath" init -input=false -no-color -lockfile=readonly
& terraform "-chdir=$BootstrapPath" fmt -check -diff
& terraform "-chdir=$BootstrapPath" validate
```

A saved provisioning plan was reviewed before applying. The original plan proposed:

```text
Plan: 6 to add, 0 to change, 0 to destroy.
```

The actual operator account must be passed as the required variable for both creation and destruction plans, for example through a local untracked `.tfvars.json` file.

The historical apply created the dedicated S3 bucket and five configuration/security resources. The independent bucket validator confirmed:

- All four Block Public Access settings enabled.
- S3 policy status not public.
- Object ownership `BucketOwnerEnforced`.
- Versioning `Enabled`.
- Default SSE-S3 `AES256`.
- A `DenyInsecureTransport` bucket policy.
- The expected account/Region, tags and an initially empty version inventory.

```powershell
& "$LabPath\scripts\test-aws-terraform-state-bucket.ps1" `
    -ProfileName "cloud-operations-lab" `
    -Region "us-east-1" `
    -ExpectedAccountId "<authorized 12-digit account ID>" `
    -RequireEmpty
```

The S3 validator inspects bucket configuration and optional emptiness. It does not create, repair or delete the bucket.

### 3. Create the exercise object with local state

In the **initial local-backend form** of the exercise configuration, initialize Terraform and inspect the `default` workspace:

```powershell
& terraform "-chdir=$ExercisePath" init -input=false
& terraform "-chdir=$ExercisePath" workspace show
```

Review the baseline plan. The recorded result was:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

The saved baseline plan was applied, creating exactly:

```text
terraform_data.lab21
```

The exercise outputs were inspected:

```powershell
& terraform "-chdir=$ExercisePath" state list
& terraform "-chdir=$ExercisePath" output -json
```

The original run recorded the object's identity and its five input/output values. A second plan proposed no changes.

Before changing the backend, the local state was copied and compared byte-for-byte using SHA-256. The recorded local files were:

```text
local-artifacts/lab21-before-migration.tfstate
local-artifacts/lab21-local-outputs.json
```

Protect these files as state artifacts, not as public screenshots or source files.

### 4. Migrate the exercise state to S3

The exercise backend declaration was changed to `backend "s3" {}`, with the actual remote backend parameters provided from the bootstrap outputs.

The recorded migration pattern was:

```powershell
$BackendPath = Join-Path $ExercisePath "lab21.s3.tfbackend.json"

& terraform "-chdir=$ExercisePath" init `
    "-migrate-state" `
    "-backend-config=$BackendPath"
```

The operator confirmed the proposed migration at Terraform's prompt. The migration then retained:

- The same `terraform_data.lab21` resource address and identity.
- The same output values as the local baseline.
- The `default` workspace.
- The expected S3 bucket/key and native locking configuration.
- A successful no-change plan.

**Do not substitute `init -reconfigure` for `init -migrate-state`** when transferring an existing state. Reconfigure changes backend initialization settings; it is not the same as explicitly migrating the existing state.

Discard saved plans created under the old backend before planning in the migrated environment. Do not reuse plans from the pre-migration state.

### 5. Independently inspect the state object

The original S3 `head-object` check reported:

| Property | Recorded observation |
|---|---|
| Remote key | `lab21/exercise/terraform.tfstate` |
| Object size | **2,625 bytes** |
| Server-side encryption | `AES256` |
| `VersionId` | Present |
| Active `.tflock` after operations | Absent |

An object existing under the expected key proves the remote state was written to S3, while preserving the resource identifier and outputs demonstrates that migration did not recreate the exercise object.

A remote-state object and its historical versions can include operational identifiers, sensitive variables and provider-managed attributes. Default SSE-S3 encrypts stored objects at rest; it does not eliminate the need for access controls, HTTPS or careful handling of downloaded state.

## Controlled concurrent locking demonstration

This experiment was conducted **in two terminals sharing the exact same backend and state key**.

### Terminal A — Hold an interactive operation before approval

```powershell
terraform "-chdir=.\labs\21-terraform-remote-state\terraform" apply `
    "-replace=terraform_data.lab21" `
    "-lock=true" `
    "-input=true" `
    "-auto-approve=false"
```

Terraform proposed replacement of the managed object and waited for an interactive answer. While the prompt was open, the S3 state-lock object existed.

**Critical safety condition:** This pending apply must **not** be approved for the test. Approving it could replace the object and invalidate the objective of demonstrating only a locking conflict.

### Terminal B — Attempt a second operation

```powershell
terraform "-chdir=.\labs\21-terraform-remote-state\terraform" plan `
    "-input=false" `
    "-lock-timeout=5s" `
    "-no-color"
```

The second Terraform operation failed to acquire the lock. The original record contained:

```text
Error acquiring the state lock
StatusCode: 412
PreconditionFailed
Operation: OperationTypeApply
```

The `412 PreconditionFailed` response is evidence of the observed lock conflict in this particular run, not an invariant error code for all storage/backend failures.

### Release the lock and confirm the original object remains

The operator entered `no` in Terminal A to **cancel** the pending replacement. The lock was released through the normal workflow.

The next plan succeeded with no changes. The original `terraform_data.lab21` ID and outputs were unchanged.

A previous `terraform console` attempt had not produced an observable live lock object. That exploratory attempt was **not accepted as proof** of locking. The successful two-terminal demonstration used the interactive pending apply.

**Do not use `-lock=false`, manually delete an active `.tflock` object, or invoke `force-unlock` while another operation might still own the lock.** Such actions can lead to concurrent state writes.

## Cleanup: order and observed inventory

Cleanup is intentionally divided into **three dependent stages**. Never destroy the state backend while the exercise still needs to read or update its state.

### 1. Destroy the exercise resource through its remote backend

The original reviewed destroy plan proposed:

```text
Plan: 0 to add, 0 to change, 1 to destroy.
```

After applying the saved plan, the recorded output was:

```text
Apply complete! Resources: 0 added, 0 changed, 1 destroyed.
```

The remote exercise state contained no managed resources, and its outputs had been removed. A final copy of the empty exercise state was preserved locally at:

```text
local-artifacts/lab21-after-destroy.tfstate
```

Keep that copy protected and outside version control. The Terraform configuration source remained committed, so a normal future plan can propose recreation of `terraform_data.lab21` if the backend is restored.

### 2. Inventory and empty every version of the S3 backend objects

The bucket used S3 Versioning. Deleting only the current state object would **not** remove all previous versions or delete markers.

The recorded pre-cleanup inventory was:

| S3 item type | Recorded count |
|---|---:|
| Versions of the state object | **2** |
| Historical versions of the lock object | **6** |
| Delete markers associated with locking | **6** |
| **Total items to remove** | **14** |

Only the intended state and lock keys were in scope. The original inventory and version-specific deletion requests were preserved outside Git:

```text
local-artifacts/lab21-before-bucket-cleanup.json
local-artifacts/lab21-delete-versions.json
```

All 14 items were deleted using explicit **object key plus `VersionId`**. The response was checked for individual deletion errors, and a new S3 version inventory confirmed that no versions or markers remained.

**Destructive operation:** Permanent deletion of specific versions cannot be undone through ordinary S3 Versioning. Confirm bucket identity, ownership, exact keys, every version ID, concurrent writers, legal retention and backup requirements before deletion. The source's `force_destroy = false` is a safeguard against deleting a non-empty bucket; it is **not a substitute** for checking deletion requests.

### 3. Destroy the six bootstrap resources

With the bucket empty and its protections rechecked, the saved bootstrap destroy plan proposed:

```text
Plan: 0 to add, 0 to change, 6 to destroy.
```

Recorded result:

```text
Apply complete! Resources: 0 added, 0 changed, 6 destroyed.
```

The final check confirmed no managed resources in the bootstrap's local state, removal of its outputs, and **absence of the S3 bucket in the authenticated AWS account's bucket listing**.

A protected local copy of the final bootstrap state was kept at:

```text
local-artifacts/lab21-bootstrap-after-destroy.tfstate
```

The bootstrap state remained local throughout; this was essential to completing removal of the S3 backend infrastructure.

## Historical evidence inventory

The repository contains **23 PNG images**. The original Portuguese README assigns thirteen to accepted execution stages; ten others are historical preparation, attempted checks or diagnostic images whose contents have not been independently established. All paths are retained below, without inventing specific outcomes for those ten.

### Accepted execution-stage evidence

| Stage | Image |
|---|---|
| Bootstrap apply | [Bootstrap resource creation](images/Clipboard_10-04-2026_42.png) |
| Local baseline plan | [Exercise creation plan](images/Clipboard_10-04-2026_44.png) |
| Baseline apply and state copy | [Local resource identity and state backup](images/Clipboard_10-04-2026_45.png) |
| Migration | [S3 state migration and validation](images/Clipboard_10-04-2026_46.png) |
| Remote object inspection | [Versioning, encryption and absence of an active lock](images/Clipboard_10-04-2026_47.png) |
| Locking conflict | [Lock object and concurrent-plan rejection](images/Clipboard_10-04-2026_52.png) |
| Lock released | [No-change plan and retained resource identity](images/Clipboard_10-04-2026_53.png) |
| Exercise destroy plan | [One planned removal](images/Clipboard_10-04-2026_54.png) |
| Exercise removal | [No managed objects and saved final state](images/Clipboard_10-04-2026_55.png) |
| Version inventory | [Versions and delete markers](images/Clipboard_10-04-2026_56.png) |
| S3 version cleanup | [Fourteen deleted items](images/Clipboard_10-04-2026_57.png) |
| Bootstrap destroy plan | [Six planned removals](images/Clipboard_10-04-2026_60.png) |
| Final cleanup | [Six bootstrap resources removed and bucket absent](images/Clipboard_10-04-2026_61.png) |

### Other preserved images

The ten additional files are preserved as neutral links. No specific activity or conclusion is assigned to an image unless the original README does so.

- [Historical image 38](images/Clipboard_10-04-2026_38.png)
- [Historical image 39](images/Clipboard_10-04-2026_39.png)
- [Historical image 40](images/Clipboard_10-04-2026_40.png)
- [Historical image 41](images/Clipboard_10-04-2026_41.png)
- [Historical image 43](images/Clipboard_10-04-2026_43.png)
- [Historical image 48](images/Clipboard_10-04-2026_48.png)
- [Historical image 49](images/Clipboard_10-04-2026_49.png)
- [Historical image 50](images/Clipboard_10-04-2026_50.png)
- [Historical image 51](images/Clipboard_10-04-2026_51.png)
- [Historical image 59](images/Clipboard_10-04-2026_59.png)

The filename inventory was verified, but **full-resolution visual interpretation and privacy inspection are still pending**.

## Security and operational limitations

**Local bootstrap state:** Protect the bootstrap's state and backups because they describe the real AWS bucket and its security resources. Deleting or losing the bootstrap state before the bucket is removed complicates safe cleanup.

**Remote state confidentiality:** S3 Versioning and SSE-S3 are useful protections, but cannot replace narrowly scoped IAM access, state secrecy, auditability, lifecycle governance and recoverability testing. The original experiment did not implement S3 Object Lock, cross-account copies or cross-region replication.

**Locking scope:** Native `.tflock` locking coordinates operations using the **same backend state key**. It is not an organization-wide concurrency gate and cannot prevent changes made through other tools, other independent state files, or AWS consoles.

**Migration integrity:** Retaining the resource ID and outputs is strong evidence that the migration preserved the managed object. It does not imply that the state can be recovered after every possible corruption or operator mistake.

**Saved plans and state:** These may contain confidential infrastructure attributes. Keep them untracked and protected. The committed provider lock file records dependency versions and hashes, not Terraform infrastructure state.

**Reproducibility:** The current committed exercise backend already points to S3, but the original bucket was deleted. A new end-to-end run requires explicitly returning to a local-backend baseline and independently provisioning a new bucket first.

**Operational approvals:** Saved plans and version-specific cleanup requests should be reviewed before application. Never remove an active lock to bypass legitimate concurrent operations.

**Costs:** The recorded AWS usage involved S3 bucket storage, object versions, requests and related transfer. Terraform's built-in `terraform_data` object does not incur AWS resource fees. A short-lived exercise can still produce S3 charges, including from retained historical versions.

**Evidence privacy:** The screenshots and locally retained state may include bucket names, account IDs, S3 VersionIds, state metadata or command output. They were not visually reviewed at full resolution for this English translation.

## Conclusion

Lab 21 recorded an end-to-end Terraform remote-state lifecycle: **local state → verified S3 migration → native locking conflict → safe lock release → resource destruction → version-aware bucket cleanup → bootstrap destruction**.

The exercise demonstrates why remote state storage, state locking, provider dependency locking, and separation of backend infrastructure from the workloads that use it are distinct responsibilities.

## Next lab

[Lab 22 — Terraform Variables, Outputs, and Modules](../22-terraform-variables-outputs-modules/)

---

[English repository overview](../../README.en.md) · [Portuguese repository overview](../../README.md)
