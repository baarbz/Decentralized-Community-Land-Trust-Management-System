;; Housing Affordability Restriction Contract
;; Manages resale price limitations and affordability calculations

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-UNIT-NOT-FOUND (err u201))
(define-constant ERR-INVALID-PRICE (err u202))
(define-constant ERR-PRICE-TOO-HIGH (err u203))
(define-constant ERR-INVALID-INPUT (err u204))

;; Maximum appreciation rate (5% per year in basis points)
(define-constant MAX-ANNUAL-APPRECIATION u500)

;; Data Variables
(define-data-var next-unit-id uint u1)
(define-data-var area-median-income uint u75000) ;; AMI in cents

;; Data Maps
(define-map housing-units
  { unit-id: uint }
  {
    parcel-id: uint,
    initial-price: uint,
    purchase-date: uint,
    current-resident: (optional principal),
    max-resale-formula: (string-ascii 50),
    affordability-level: uint ;; Percentage of AMI (e.g., 80 for 80% AMI)
  }
)

(define-map price-history
  { unit-id: uint, sale-date: uint }
  {
    sale-price: uint,
    buyer: principal,
    seller: (optional principal)
  }
)

(define-map affordability-formulas
  { formula-name: (string-ascii 50) }
  {
    base-multiplier: uint, ;; In basis points
    annual-appreciation: uint, ;; In basis points
    ami-percentage: uint ;; Target AMI percentage
  }
)

;; Public Functions

;; Register a new housing unit
(define-public (register-housing-unit
  (parcel-id uint)
  (initial-price uint)
  (affordability-level uint)
  (formula-name (string-ascii 50)))
  (let ((unit-id (var-get next-unit-id)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> initial-price u0) ERR-INVALID-PRICE)
    (asserts! (and (>= affordability-level u30) (<= affordability-level u120)) ERR-INVALID-INPUT)

    (map-set housing-units
      { unit-id: unit-id }
      {
        parcel-id: parcel-id,
        initial-price: initial-price,
        purchase-date: block-height,
        current-resident: none,
        max-resale-formula: formula-name,
        affordability-level: affordability-level
      }
    )

    (map-set price-history
      { unit-id: unit-id, sale-date: block-height }
      {
        sale-price: initial-price,
        buyer: CONTRACT-OWNER,
        seller: none
      }
    )

    (var-set next-unit-id (+ unit-id u1))
    (ok unit-id)
  )
)

;; Calculate maximum resale price
(define-public (calculate-max-resale-price (unit-id uint))
  (let (
    (unit-data (unwrap! (map-get? housing-units { unit-id: unit-id }) ERR-UNIT-NOT-FOUND))
    (years-held (/ (- block-height (get purchase-date unit-data)) u52560)) ;; Approximate blocks per year
    (initial-price (get initial-price unit-data))
    (appreciation-amount (/ (* initial-price (* years-held MAX-ANNUAL-APPRECIATION)) u10000))
  )
    (ok (+ initial-price appreciation-amount))
  )
)

;; Validate proposed sale price
(define-public (validate-sale-price (unit-id uint) (proposed-price uint))
  (let ((max-price (unwrap! (calculate-max-resale-price unit-id) ERR-UNIT-NOT-FOUND)))
    (if (<= proposed-price max-price)
      (ok true)
      ERR-PRICE-TOO-HIGH
    )
  )
)

;; Record a unit sale
(define-public (record-unit-sale
  (unit-id uint)
  (sale-price uint)
  (buyer principal))
  (let ((unit-data (unwrap! (map-get? housing-units { unit-id: unit-id }) ERR-UNIT-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-ok (validate-sale-price unit-id sale-price)) ERR-PRICE-TOO-HIGH)

    (map-set price-history
      { unit-id: unit-id, sale-date: block-height }
      {
        sale-price: sale-price,
        buyer: buyer,
        seller: (get current-resident unit-data)
      }
    )

    (map-set housing-units
      { unit-id: unit-id }
      (merge unit-data {
        current-resident: (some buyer),
        purchase-date: block-height
      })
    )
    (ok true)
  )
)

;; Update area median income
(define-public (update-area-median-income (new-ami uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> new-ami u0) ERR-INVALID-INPUT)
    (var-set area-median-income new-ami)
    (ok true)
  )
)

;; Set affordability formula
(define-public (set-affordability-formula
  (formula-name (string-ascii 50))
  (base-multiplier uint)
  (annual-appreciation uint)
  (ami-percentage uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= annual-appreciation MAX-ANNUAL-APPRECIATION) ERR-INVALID-INPUT)

    (map-set affordability-formulas
      { formula-name: formula-name }
      {
        base-multiplier: base-multiplier,
        annual-appreciation: annual-appreciation,
        ami-percentage: ami-percentage
      }
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get housing unit details
(define-read-only (get-housing-unit (unit-id uint))
  (map-get? housing-units { unit-id: unit-id })
)

;; Get price history for a unit
(define-read-only (get-price-history (unit-id uint) (sale-date uint))
  (map-get? price-history { unit-id: unit-id, sale-date: sale-date })
)

;; Get current area median income
(define-read-only (get-area-median-income)
  (var-get area-median-income)
)

;; Calculate affordability threshold for income level
(define-read-only (calculate-affordability-threshold (income uint) (ami-percentage uint))
  (/ (* income ami-percentage) u100)
)

;; Get affordability formula
(define-read-only (get-affordability-formula (formula-name (string-ascii 50)))
  (map-get? affordability-formulas { formula-name: formula-name })
)

;; Check if unit is affordable for income level
(define-read-only (is-unit-affordable (unit-id uint) (buyer-income uint))
  (match (map-get? housing-units { unit-id: unit-id })
    unit-data
    (let (
      (required-income (/ (* (get initial-price unit-data) u100) (get affordability-level unit-data)))
    )
      (<= required-income buyer-income)
    )
    false
  )
)

;; Get total housing units
(define-read-only (get-total-units)
  (- (var-get next-unit-id) u1)
)
