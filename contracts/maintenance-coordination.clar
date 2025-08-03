;; Property Maintenance Coordination Contract
;; Manages property maintenance, repairs, and contractor coordination

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-REQUEST-NOT-FOUND (err u401))
(define-constant ERR-CONTRACTOR-NOT-FOUND (err u402))
(define-constant ERR-INSUFFICIENT-FUNDS (err u403))
(define-constant ERR-INVALID-INPUT (err u404))
(define-constant ERR-REQUEST-COMPLETED (err u405))

;; Priority levels
(define-constant PRIORITY-LOW u1)
(define-constant PRIORITY-MEDIUM u2)
(define-constant PRIORITY-HIGH u3)
(define-constant PRIORITY-EMERGENCY u4)

;; Data Variables
(define-data-var next-request-id uint u1)
(define-data-var next-contractor-id uint u1)
(define-data-var maintenance-fund uint u0)

;; Data Maps
(define-map maintenance-requests
  { request-id: uint }
  {
    property-id: uint,
    requester: principal,
    description: (string-ascii 500),
    priority: uint,
    estimated-cost: uint,
    actual-cost: (optional uint),
    assigned-contractor: (optional uint),
    status: (string-ascii 20), ;; "open", "assigned", "in-progress", "completed", "cancelled"
    created-date: uint,
    completion-date: (optional uint)
  }
)

(define-map contractors
  { contractor-id: uint }
  {
    contractor-address: principal,
    company-name: (string-ascii 100),
    specialties: (string-ascii 200),
    rating: uint, ;; Out of 100
    total-jobs: uint,
    is-active: bool,
    registration-date: uint
  }
)

(define-map contractor-bids
  { request-id: uint, contractor-id: uint }
  {
    bid-amount: uint,
    estimated-duration: uint, ;; in days
    bid-date: uint,
    notes: (string-ascii 300)
  }
)

(define-map maintenance-history
  { property-id: uint, completion-date: uint }
  {
    request-id: uint,
    work-performed: (string-ascii 500),
    contractor-id: uint,
    cost: uint,
    quality-rating: uint
  }
)

(define-map fund-contributions
  { contributor: principal, contribution-date: uint }
  {
    amount: uint,
    purpose: (string-ascii 100)
  }
)

;; Public Functions

;; Submit maintenance request
(define-public (submit-maintenance-request
  (property-id uint)
  (description (string-ascii 500))
  (priority uint)
  (estimated-cost uint))
  (let ((request-id (var-get next-request-id)))
    (asserts! (and (>= priority PRIORITY-LOW) (<= priority PRIORITY-EMERGENCY)) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (> estimated-cost u0) ERR-INVALID-INPUT)

    (map-set maintenance-requests
      { request-id: request-id }
      {
        property-id: property-id,
        requester: tx-sender,
        description: description,
        priority: priority,
        estimated-cost: estimated-cost,
        actual-cost: none,
        assigned-contractor: none,
        status: "open",
        created-date: block-height,
        completion-date: none
      }
    )

    (var-set next-request-id (+ request-id u1))
    (ok request-id)
  )
)

;; Register contractor
(define-public (register-contractor
  (contractor-address principal)
  (company-name (string-ascii 100))
  (specialties (string-ascii 200)))
  (let ((contractor-id (var-get next-contractor-id)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len company-name) u0) ERR-INVALID-INPUT)

    (map-set contractors
      { contractor-id: contractor-id }
      {
        contractor-address: contractor-address,
        company-name: company-name,
        specialties: specialties,
        rating: u80, ;; Default rating
        total-jobs: u0,
        is-active: true,
        registration-date: block-height
      }
    )

    (var-set next-contractor-id (+ contractor-id u1))
    (ok contractor-id)
  )
)

;; Submit contractor bid
(define-public (submit-bid
  (request-id uint)
  (contractor-id uint)
  (bid-amount uint)
  (estimated-duration uint)
  (notes (string-ascii 300)))
  (let (
    (request-data (unwrap! (map-get? maintenance-requests { request-id: request-id }) ERR-REQUEST-NOT-FOUND))
    (contractor-data (unwrap! (map-get? contractors { contractor-id: contractor-id }) ERR-CONTRACTOR-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get contractor-address contractor-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request-data) "open") ERR-INVALID-INPUT)
    (asserts! (> bid-amount u0) ERR-INVALID-INPUT)

    (map-set contractor-bids
      { request-id: request-id, contractor-id: contractor-id }
      {
        bid-amount: bid-amount,
        estimated-duration: estimated-duration,
        bid-date: block-height,
        notes: notes
      }
    )
    (ok true)
  )
)

;; Assign contractor to request
(define-public (assign-contractor (request-id uint) (contractor-id uint))
  (let (
    (request-data (unwrap! (map-get? maintenance-requests { request-id: request-id }) ERR-REQUEST-NOT-FOUND))
    (contractor-data (unwrap! (map-get? contractors { contractor-id: contractor-id }) ERR-CONTRACTOR-NOT-FOUND))
    (bid-data (unwrap! (map-get? contractor-bids { request-id: request-id, contractor-id: contractor-id }) ERR-INVALID-INPUT))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request-data) "open") ERR-INVALID-INPUT)
    (asserts! (>= (var-get maintenance-fund) (get bid-amount bid-data)) ERR-INSUFFICIENT-FUNDS)

    (map-set maintenance-requests
      { request-id: request-id }
      (merge request-data {
        assigned-contractor: (some contractor-id),
        status: "assigned"
      })
    )
    (ok true)
  )
)

;; Update request status
(define-public (update-request-status
  (request-id uint)
  (new-status (string-ascii 20))
  (actual-cost (optional uint)))
  (let ((request-data (unwrap! (map-get? maintenance-requests { request-id: request-id }) ERR-REQUEST-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set maintenance-requests
      { request-id: request-id }
      (merge request-data {
        status: new-status,
        actual-cost: actual-cost,
        completion-date: (if (is-eq new-status "completed") (some block-height) none)
      })
    )

    ;; If completed, record in maintenance history
    (if (is-eq new-status "completed")
      (match (get assigned-contractor request-data)
        contractor-id
        (match actual-cost
          cost
          (map-set maintenance-history
            { property-id: (get property-id request-data), completion-date: block-height }
            {
              request-id: request-id,
              work-performed: (get description request-data),
              contractor-id: contractor-id,
              cost: cost,
              quality-rating: u0 ;; To be updated later
            }
          )
          false
        )
        false
      )
      false
    )
    (ok true)
  )
)

;; Add funds to maintenance fund
(define-public (contribute-to-maintenance-fund (amount uint) (purpose (string-ascii 100)))
  (begin
    (asserts! (> amount u0) ERR-INVALID-INPUT)

    (map-set fund-contributions
      { contributor: tx-sender, contribution-date: block-height }
      {
        amount: amount,
        purpose: purpose
      }
    )

    (var-set maintenance-fund (+ (var-get maintenance-fund) amount))
    (ok true)
  )
)

;; Rate completed work
(define-public (rate-completed-work
  (property-id uint)
  (completion-date uint)
  (quality-rating uint))
  (let ((history-data (unwrap! (map-get? maintenance-history { property-id: property-id, completion-date: completion-date }) ERR-REQUEST-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= quality-rating u1) (<= quality-rating u100)) ERR-INVALID-INPUT)

    (map-set maintenance-history
      { property-id: property-id, completion-date: completion-date }
      (merge history-data { quality-rating: quality-rating })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get maintenance request details
(define-read-only (get-maintenance-request (request-id uint))
  (map-get? maintenance-requests { request-id: request-id })
)

;; Get contractor details
(define-read-only (get-contractor (contractor-id uint))
  (map-get? contractors { contractor-id: contractor-id })
)

;; Get contractor bid
(define-read-only (get-contractor-bid (request-id uint) (contractor-id uint))
  (map-get? contractor-bids { request-id: request-id, contractor-id: contractor-id })
)

;; Get maintenance history
(define-read-only (get-maintenance-history (property-id uint) (completion-date uint))
  (map-get? maintenance-history { property-id: property-id, completion-date: completion-date })
)

;; Get current maintenance fund balance
(define-read-only (get-maintenance-fund-balance)
  (var-get maintenance-fund)
)

;; Get fund contribution
(define-read-only (get-fund-contribution (contributor principal) (contribution-date uint))
  (map-get? fund-contributions { contributor: contributor, contribution-date: contribution-date })
)

;; Check if request is open for bids
(define-read-only (is-request-open (request-id uint))
  (match (map-get? maintenance-requests { request-id: request-id })
    request-data (is-eq (get status request-data) "open")
    false
  )
)

;; Get total maintenance requests
(define-read-only (get-total-requests)
  (- (var-get next-request-id) u1)
)

;; Get total contractors
(define-read-only (get-total-contractors)
  (- (var-get next-contractor-id) u1)
)
