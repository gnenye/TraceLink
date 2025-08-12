;; Supply Chain Verification System
;; Enables tracking of products through the supply chain with
;; immutable records and verification at each step of the process

;; Item definitions
(define-map inventory-items
  { item-id: uint }
  {
    title: (string-utf8 128),
    details: (string-utf8 1024),
    producer: principal,
    lot-number: (string-ascii 64),
    created-at: uint,
    state: (string-ascii 32),  ;; "created", "in-transit", "delivered", "sold", "recalled"
    item-category: (string-ascii 64),
    source-location: (string-utf8 128),
    current-holder: principal,
    target-destination: (optional (string-utf8 128)),
    anticipated-delivery: (optional uint),
    info-uri: (optional (string-utf8 256))
  }
)

;; Supply chain waypoints
(define-map waypoints
  { item-id: uint, waypoint-id: uint }
  {
    position: (string-utf8 128),
    recorded-time: uint,
    handler: principal,
    confirmed-by: principal,
    waypoint-category: (string-ascii 32),  ;; "manufacture", "shipping", "customs", "warehouse", "retail", "delivery"
    temp-reading: (optional int),         ;; For temperature-sensitive goods
    moisture-level: (optional uint),           ;; For humidity-sensitive goods
    remarks: (optional (string-utf8 512)),
    proof-hash: (buff 32)         ;; Hash of checkpoint attestation document
  }
)

;; Authorized validators for each company
(define-map organization-validators
  { organization: principal, validator: principal }
  {
    full-name: (string-utf8 128),
    position: (string-ascii 64),
    granted-at: uint,
    granted-by: principal,
    enabled: bool
  }
)

;; Ownership transfers
(define-map ownership-transfers
  { item-id: uint, handover-id: uint }
  {
    sender: principal,
    receiver: principal,
    started-at: uint,
    finished-at: (optional uint),
    state: (string-ascii 32),  ;; "pending", "completed", "rejected", "cancelled"
    requirements: (optional (string-utf8 512))
  }
)

;; Certifications and compliance
(define-map compliance-records
  { item-id: uint, compliance-type: (string-ascii 64) }
  {
    authority: principal,
    granted-at: uint,
    expires-at: uint,
    document-hash: (buff 32),
    document-uri: (optional (string-utf8 256)),
    state: (string-ascii 32)  ;; "valid", "expired", "revoked"
  }
)

;; Next available IDs
(define-data-var next-item-id uint u0)
(define-map next-waypoint-id { item-id: uint } { id: uint })
(define-map next-handover-id { item-id: uint } { id: uint })

;; Helper function to convert string to buffer for hashing
(define-private (utf8-string-to-buffer (input (string-utf8 512)))
  ;; In a real implementation, you would convert the string to bytes
  0x68656c6c6f20776f726c64 ;; Example buffer (represents "hello world" in hex)
)

;; Helper function to convert ascii string to buffer for hashing
(define-private (ascii-string-to-buffer (input (string-ascii 64)))
  ;; In a real implementation, you would convert the string to bytes
  0x68656c6c6f20776f726c64 ;; Example buffer (represents "hello world" in hex)
)

;; Helper function to convert principal to string
(define-private (principal-to-text (input principal))
  u"principal" ;; Simplified implementation
)

;; Register a new item
(define-public (register-item
                (title (string-utf8 128))
                (details (string-utf8 1024))
                (lot-number (string-ascii 64))
                (item-category (string-ascii 64))
                (source-location (string-utf8 128))
                (info-uri (optional (string-utf8 256))))
  (let
    ((item-id (var-get next-item-id)))
    
    ;; Create the item record
    (map-set inventory-items
      { item-id: item-id }
      {
        title: title,
        details: details,
        producer: tx-sender,
        lot-number: lot-number,
        created-at: block-height,
        state: "created",
        item-category: item-category,
        source-location: source-location,
        current-holder: tx-sender,
        target-destination: none,
        anticipated-delivery: none,
        info-uri: info-uri
      }
    )
    
    ;; Initialize waypoint counter
    (map-set next-waypoint-id
      { item-id: item-id }
      { id: u0 }
    )
    
    ;; Initialize handover counter
    (map-set next-handover-id
      { item-id: item-id }
      { id: u0 }
    )
    
    ;; Create initial manufacturing waypoint
    (try! (add-waypoint
            item-id
            source-location
            "manufacture"
            none
            none
            (some u"Item manufactured with lot number")
            (sha256 (ascii-string-to-buffer lot-number))
          ))
    
    ;; Increment item ID counter
    (var-set next-item-id (+ item-id u1))
    
    (ok item-id)
  )
)

;; Add a waypoint to an item's supply chain journey
(define-public (add-waypoint
                (item-id uint)
                (position (string-utf8 128))
                (waypoint-category (string-ascii 32))
                (temp-reading (optional int))
                (moisture-level (optional uint))
                (remarks (optional (string-utf8 512)))
                (proof-hash (buff 32)))
  (let
    ((item (unwrap! (map-get? inventory-items { item-id: item-id }) (err u"Item not found")))
     (waypoint-counter (unwrap! (map-get? next-waypoint-id { item-id: item-id }) 
                                 (err u"Counter not found")))
     (waypoint-id (get id waypoint-counter)))
    
    ;; Validate
    (asserts! (or (is-eq tx-sender (get current-holder item)) 
                  (is-organization-validator (get current-holder item) tx-sender))
              (err u"Not authorized to add waypoint"))
    (asserts! (not (is-eq (get state item) "recalled")) (err u"Item has been recalled"))
    
    ;; Create the waypoint
    (map-set waypoints
      { item-id: item-id, waypoint-id: waypoint-id }
      {
        position: position,
        recorded-time: block-height,
        handler: (get current-holder item),
        confirmed-by: tx-sender,
        waypoint-category: waypoint-category,
        temp-reading: temp-reading,
        moisture-level: moisture-level,
        remarks: remarks,
        proof-hash: proof-hash
      }
    )
    
    ;; Update item state based on waypoint category
    (map-set inventory-items
      { item-id: item-id }
      (merge item 
        { 
          state: (if (is-eq waypoint-category "delivery") "delivered" 
                    (if (is-eq waypoint-category "retail-sale") "sold" "in-transit"))
        }
      )
    )
    
    ;; Increment waypoint counter
    (map-set next-waypoint-id
      { item-id: item-id }
      { id: (+ waypoint-id u1) }
    )
    
    (ok waypoint-id)
  )
)

;; Check if a principal is an authorized validator for an organization
(define-private (is-organization-validator (organization principal) (validator principal))
  (match (map-get? organization-validators { organization: organization, validator: validator })
    validator-info (get enabled validator-info)
    false
  )
)

;; Authorize a validator for an organization
(define-public (authorize-validator
                (validator principal)
                (full-name (string-utf8 128))
                (position (string-ascii 64)))
  (begin
    ;; Set validator as authorized
    (map-set organization-validators
      { organization: tx-sender, validator: validator }
      {
        full-name: full-name,
        position: position,
        granted-at: block-height,
        granted-by: tx-sender,
        enabled: true
      }
    )
    
    (ok true)
  )
)

;; Revoke a validator's authorization
(define-public (revoke-validator (validator principal))
  (let
    ((validator-info (unwrap! (map-get? organization-validators { organization: tx-sender, validator: validator })
                            (err u"Validator not found"))))
    
    (map-set organization-validators
      { organization: tx-sender, validator: validator }
      (merge validator-info { enabled: false })
    )
    
    (ok true)
  )
)

;; Initiate ownership handover of an item
(define-public (initiate-handover
                (item-id uint)
                (receiver principal)
                (requirements (optional (string-utf8 512))))
  (let
    ((item (unwrap! (map-get? inventory-items { item-id: item-id }) (err u"Item not found")))
     (handover-counter (unwrap! (map-get? next-handover-id { item-id: item-id }) 
                               (err u"Counter not found")))
     (handover-id (get id handover-counter)))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get current-holder item)) 
              (err u"Only current holder can initiate handover"))
    (asserts! (not (is-eq (get state item) "recalled")) 
              (err u"Item has been recalled"))
    
    ;; Create handover record
    (map-set ownership-transfers
      { item-id: item-id, handover-id: handover-id }
      {
        sender: tx-sender,
        receiver: receiver,
        started-at: block-height,
        finished-at: none,
        state: "pending",
        requirements: requirements
      }
    )
    
    ;; Increment handover counter
    (map-set next-handover-id
      { item-id: item-id }
      { id: (+ handover-id u1) }
    )
    
    (ok handover-id)
  )
)

;; Accept an ownership handover
(define-public (accept-handover (item-id uint) (handover-id uint))
  (let
    ((item (unwrap! (map-get? inventory-items { item-id: item-id }) (err u"Item not found")))
     (handover (unwrap! (map-get? ownership-transfers { item-id: item-id, handover-id: handover-id })
                       (err u"Handover not found"))))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get receiver handover)) (err u"Only receiver can accept"))
    (asserts! (is-eq (get state handover) "pending") (err u"Handover not pending"))
    
    ;; Update handover record
    (map-set ownership-transfers
      { item-id: item-id, handover-id: handover-id }
      (merge handover 
        { 
          finished-at: (some block-height),
          state: "completed"
        }
      )
    )
    
    ;; Update item holder
    (map-set inventory-items
      { item-id: item-id }
      (merge item { current-holder: tx-sender })
    )
    
    ;; Add a waypoint for the ownership handover
    (try! (add-waypoint
            item-id
            u"ownership-handover" ;; Generic location for handover as utf8
            "transfer"
            none
            none
            (some u"Ownership transferred")
            (sha256 (utf8-string-to-buffer u"ownership-handover"))
          ))
    
    (ok true)
  )
)

;; Reject an ownership handover
(define-public (reject-handover (item-id uint) (handover-id uint) (reason (string-utf8 512)))
  (let
    ((handover (unwrap! (map-get? ownership-transfers { item-id: item-id, handover-id: handover-id })
                       (err u"Handover not found"))))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get receiver handover)) (err u"Only receiver can reject"))
    (asserts! (is-eq (get state handover) "pending") (err u"Handover not pending"))
    
    ;; Update handover record
    (map-set ownership-transfers
      { item-id: item-id, handover-id: handover-id }
      (merge handover 
        { 
          finished-at: (some block-height),
          state: "rejected",
          requirements: (some reason)
        }
      )
    )
    
    (ok true)
  )
)

;; Cancel a pending handover (only current holder)
(define-public (cancel-handover (item-id uint) (handover-id uint))
  (let
    ((handover (unwrap! (map-get? ownership-transfers { item-id: item-id, handover-id: handover-id })
                       (err u"Handover not found"))))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get sender handover)) (err u"Only sender can cancel"))
    (asserts! (is-eq (get state handover) "pending") (err u"Handover not pending"))
    
    ;; Update handover record
    (map-set ownership-transfers
      { item-id: item-id, handover-id: handover-id }
      (merge handover 
        { 
          finished-at: (some block-height),
          state: "cancelled"
        }
      )
    )
    
    (ok true)
  )
)

;; Add compliance record to an item
(define-public (add-compliance-record
                (item-id uint)
                (compliance-type (string-ascii 64))
                (expires-at uint)
                (document-hash (buff 32))
                (document-uri (optional (string-utf8 256))))
  (let
    ((item (unwrap! (map-get? inventory-items { item-id: item-id }) (err u"Item not found"))))
    
    ;; Validate
    (asserts! (or (is-eq tx-sender (get producer item)) 
                  (is-organization-validator (get producer item) tx-sender))
              (err u"Not authorized to add compliance record"))
    (asserts! (> expires-at block-height) (err u"Compliance record must be valid for future blocks"))
    
    ;; Add compliance record
    (map-set compliance-records
      { item-id: item-id, compliance-type: compliance-type }
      {
        authority: tx-sender,
        granted-at: block-height,
        expires-at: expires-at,
        document-hash: document-hash,
        document-uri: document-uri,
        state: "valid"
      }
    )
    
    (ok true)
  )
)

;; Revoke a compliance record
(define-public (revoke-compliance-record (item-id uint) (compliance-type (string-ascii 64)))
  (let
    ((compliance-record (unwrap! (map-get? compliance-records 
                               { item-id: item-id, compliance-type: compliance-type })
                             (err u"Compliance record not found"))))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get authority compliance-record)) 
              (err u"Only authority can revoke compliance record"))
    
    ;; Update compliance record
    (map-set compliance-records
      { item-id: item-id, compliance-type: compliance-type }
      (merge compliance-record { state: "revoked" })
    )
    
    (ok true)
  )
)

;; Issue an item recall
(define-public (recall-item (item-id uint) (reason (string-utf8 512)))
  (let
    ((item (unwrap! (map-get? inventory-items { item-id: item-id }) (err u"Item not found"))))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get producer item)) 
              (err u"Only producer can recall item"))
    
    ;; Update item state
    (map-set inventory-items
      { item-id: item-id }
      (merge item { state: "recalled" })
    )
    
    ;; Add a waypoint for the recall
    (try! (add-waypoint
            item-id
            u"recall" ;; Using utf8 string for position
            "recall"
            none
            none
            (some reason)
            (sha256 (utf8-string-to-buffer reason))
          ))
    
    (ok true)
  )
)

;; Set target destination and anticipated delivery
(define-public (set-delivery-details
                (item-id uint)
                (target-destination (string-utf8 128))
                (anticipated-delivery uint))
  (let
    ((item (unwrap! (map-get? inventory-items { item-id: item-id }) (err u"Item not found"))))
    
    ;; Validate
    (asserts! (or (is-eq tx-sender (get current-holder item)) 
                  (is-organization-validator (get current-holder item) tx-sender))
              (err u"Not authorized to set delivery details"))
    
    ;; Update item
    (map-set inventory-items
      { item-id: item-id }
      (merge item 
        { 
          target-destination: (some target-destination),
          anticipated-delivery: (some anticipated-delivery)
        }
      )
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get item details
(define-read-only (get-item-details (item-id uint))
  (ok (unwrap! (map-get? inventory-items { item-id: item-id }) (err u"Item not found")))
)

;; Get waypoint details
(define-read-only (get-waypoint (item-id uint) (waypoint-id uint))
  (ok (unwrap! (map-get? waypoints { item-id: item-id, waypoint-id: waypoint-id })
              (err u"Waypoint not found")))
)

;; Get handover details
(define-read-only (get-handover (item-id uint) (handover-id uint))
  (ok (unwrap! (map-get? ownership-transfers { item-id: item-id, handover-id: handover-id })
              (err u"Handover not found")))
)

;; Get compliance record details
(define-read-only (get-compliance-record (item-id uint) (compliance-type (string-ascii 64)))
  (ok (unwrap! (map-get? compliance-records { item-id: item-id, compliance-type: compliance-type })
              (err u"Compliance record not found")))
)

;; Check if compliance record is valid
(define-read-only (is-compliance-record-valid (item-id uint) (compliance-type (string-ascii 64)))
  (match (map-get? compliance-records { item-id: item-id, compliance-type: compliance-type })
    compliance-record (and (is-eq (get state compliance-record) "valid")
                       (> (get expires-at compliance-record) block-height))
    false
  )
)

;; Verify item authenticity (basic check)
(define-read-only (verify-item-authenticity (item-id uint))
  (match (map-get? inventory-items { item-id: item-id })
    item (ok {
              authentic: true,
              producer: (get producer item),
              lot-number: (get lot-number item),
              state: (get state item)
            })
    (err u"Item not found")
  )
)
