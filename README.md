# TraceLink – Supply Chain Verification Smart Contract

## Overview

**TraceLink** is a blockchain-based supply chain verification system built in Clarity. It enables transparent and tamper-proof tracking of products from manufacturing to final delivery, ensuring authenticity, compliance, and accountability at every step.

With TraceLink, manufacturers, verifiers, and custodians can record immutable supply chain events, manage custody transfers, and issue product certifications. This solution addresses the growing need for trusted product traceability in industries such as pharmaceuticals, food safety, and luxury goods.

---

## Key Features

* **Product Registration** – Register new products with detailed metadata, including batch codes, origin, and manufacturing details.
* **Immutable Checkpoints** – Record verified checkpoints at every stage of the supply chain, including manufacturing, shipping, customs, and delivery.
* **Custody Transfers** – Securely transfer product custody with approval workflows for acceptance, rejection, and cancellation.
* **Authorized Verifiers** – Assign and manage authorized verifiers for each company to validate supply chain events.
* **Compliance & Certifications** – Add, revoke, and validate product certifications for quality control and regulatory compliance.
* **Product Recalls** – Issue recalls with recorded reasons and blockchain proof.
* **Shipping Details** – Update final destination and expected delivery times.
* **Verification Tools** – Read-only functions to check authenticity, retrieve details, and validate certifications.

---

## Contract Components

### Data Structures

* **products** – Stores product details, current custodian, and status.
* **checkpoints** – Records supply chain events with verification details.
* **company-verifiers** – Maintains a list of authorized verifiers for each company.
* **custody-transfers** – Tracks custody change requests and their status.
* **certifications** – Stores product certifications, validity, and status.

### State Variables

* `next-product-id` – Tracks the next product identifier.
* `next-checkpoint-id` – Tracks checkpoint IDs per product.
* `next-transfer-id` – Tracks transfer IDs per product.

---

## Public Functions

* **register-product** – Registers a new product and creates the initial manufacturing checkpoint.
* **add-checkpoint** – Adds a verified supply chain event for a product.
* **authorize-verifier** – Grants verifier privileges for a company.
* **revoke-verifier** – Removes verifier privileges.
* **initiate-transfer** – Initiates a custody transfer request.
* **accept-transfer** – Approves and completes a transfer.
* **reject-transfer** – Rejects a pending transfer.
* **cancel-transfer** – Cancels a pending transfer.
* **add-certification** – Issues a compliance certificate for a product.
* **revoke-certification** – Revokes a compliance certificate.
* **recall-product** – Issues a recall for a product.
* **set-shipping-details** – Updates final destination and expected delivery date.

---

## Read-Only Functions

* **get-product-details** – Retrieves product details.
* **get-checkpoint** – Retrieves details of a supply chain checkpoint.
* **get-transfer** – Retrieves details of a custody transfer.
* **get-certification** – Retrieves certification details.
* **is-certification-valid** – Checks if a certification is valid.
* **verify-product-authenticity** – Performs a basic authenticity check.

---

## Authorization Rules

* Only **current custodians** or **authorized verifiers** can add checkpoints.
* Only **manufacturers** or **authorized verifiers** can issue certifications.
* Only the **manufacturer** can recall a product.
* Only **transfer recipients** can accept or reject custody transfers.
* Only the **sender** can cancel a pending custody transfer.

---

## Example Use Case Flow

1. Manufacturer registers a new product using `register-product`.
2. Checkpoints are added as the product moves through the supply chain using `add-checkpoint`.
3. Custody transfers are initiated and accepted or rejected via `initiate-transfer`, `accept-transfer`, and `reject-transfer`.
4. Certifications are issued with `add-certification` and can be validated later using `is-certification-valid`.
5. If a defect is found, the manufacturer issues a recall using `recall-product`.