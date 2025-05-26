;; Privacy Management Contract
;; Controls customer data usage and privacy preferences

(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_INVALID_PERMISSION (err u501))
(define-constant ERR_NOT_FOUND (err u502))
(define-constant ERR_CONSENT_REQUIRED (err u503))

;; Privacy levels
(define-constant PRIVACY_PUBLIC u1)
(define-constant PRIVACY_RESTRICTED u2)
(define-constant PRIVACY_PRIVATE u3)
(define-constant PRIVACY_ANONYMOUS u4)

;; Data usage types
(define-constant USAGE_ANALYTICS u1)
(define-constant USAGE_MARKETING u2)
(define-constant USAGE_PERSONALIZATION u3)
(define-constant USAGE_RESEARCH u4)

;; Data structures
(define-map customer-privacy-settings
  { customer-id: principal }
  {
    privacy-level: uint,
    data-sharing-consent: bool,
    analytics-consent: bool,
    marketing-consent: bool,
    personalization-consent: bool,
    data-retention-period: uint,
    last-updated: uint
  }
)

(define-map data-access-permissions
  { customer-id: principal, retailer-id: principal }
  {
    access-level: uint,
    permitted-usage: (list 4 uint),
    expiry-date: uint,
    granted-at: uint,
    revoked: bool
  }
)

(define-map data-usage-log
  { log-id: uint }
  {
    customer-id: principal,
    retailer-id: principal,
    data-type: uint,
    usage-type: uint,
    timestamp: uint,
    purpose: (string-ascii 100),
    authorized: bool
  }
)

(define-data-var next-log-id uint u1)

;; Public functions
(define-public (set-privacy-preferences
  (privacy-level uint)
  (data-sharing-consent bool)
  (analytics-consent bool)
  (marketing-consent bool)
  (personalization-consent bool)
  (retention-period uint))
  (begin
    (asserts! (<= privacy-level u4) ERR_INVALID_PERMISSION)
    (asserts! (> privacy-level u0) ERR_INVALID_PERMISSION)

    (map-set customer-privacy-settings
      { customer-id: tx-sender }
      {
        privacy-level: privacy-level,
        data-sharing-consent: data-sharing-consent,
        analytics-consent: analytics-consent,
        marketing-consent: marketing-consent,
        personalization-consent: personalization-consent,
        data-retention-period: retention-period,
        last-updated: block-height
      }
    )
    (ok true)
  )
)

(define-public (grant-data-access
  (retailer-id principal)
  (access-level uint)
  (permitted-usage (list 4 uint))
  (expiry-blocks uint))
  (begin
    (asserts! (<= access-level u4) ERR_INVALID_PERMISSION)
    (asserts! (> access-level u0) ERR_INVALID_PERMISSION)

    (map-set data-access-permissions
      { customer-id: tx-sender, retailer-id: retailer-id }
      {
        access-level: access-level,
        permitted-usage: permitted-usage,
        expiry-date: (+ block-height expiry-blocks),
        granted-at: block-height,
        revoked: false
      }
    )
    (ok true)
  )
)

(define-public (revoke-data-access (retailer-id principal))
  (match (map-get? data-access-permissions { customer-id: tx-sender, retailer-id: retailer-id })
    permission-data
    (begin
      (map-set data-access-permissions
        { customer-id: tx-sender, retailer-id: retailer-id }
        (merge permission-data { revoked: true })
      )
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

(define-public (log-data-usage
  (customer-id principal)
  (data-type uint)
  (usage-type uint)
  (purpose (string-ascii 100)))
  (let ((log-id (var-get next-log-id)))
    (let ((authorized (check-usage-authorization customer-id tx-sender usage-type)))
      (map-set data-usage-log
        { log-id: log-id }
        {
          customer-id: customer-id,
          retailer-id: tx-sender,
          data-type: data-type,
          usage-type: usage-type,
          timestamp: block-height,
          purpose: purpose,
          authorized: authorized
        }
      )

      (var-set next-log-id (+ log-id u1))
      (if authorized
        (ok log-id)
        ERR_CONSENT_REQUIRED
      )
    )
  )
)

(define-private (check-usage-authorization (customer-id principal) (retailer-id principal) (usage-type uint))
  (match (map-get? data-access-permissions { customer-id: customer-id, retailer-id: retailer-id })
    permission-data
    (and
      (not (get revoked permission-data))
      (< block-height (get expiry-date permission-data))
      (is-some (index-of (get permitted-usage permission-data) usage-type))
      (check-consent customer-id usage-type)
    )
    false
  )
)

(define-private (check-consent (customer-id principal) (usage-type uint))
  (match (map-get? customer-privacy-settings { customer-id: customer-id })
    settings
    (if (is-eq usage-type USAGE_ANALYTICS)
      (get analytics-consent settings)
      (if (is-eq usage-type USAGE_MARKETING)
        (get marketing-consent settings)
        (if (is-eq usage-type USAGE_PERSONALIZATION)
          (get personalization-consent settings)
          (get data-sharing-consent settings)
        )
      )
    )
    false
  )
)

;; Read-only functions
(define-read-only (get-privacy-settings (customer-id principal))
  (map-get? customer-privacy-settings { customer-id: customer-id })
)

(define-read-only (get-data-access-permission (customer-id principal) (retailer-id principal))
  (map-get? data-access-permissions { customer-id: customer-id, retailer-id: retailer-id })
)

(define-read-only (get-data-usage-log (log-id uint))
  (map-get? data-usage-log { log-id: log-id })
)

(define-read-only (check-data-access (customer-id principal) (retailer-id principal) (usage-type uint))
  (check-usage-authorization customer-id retailer-id usage-type)
)

(define-read-only (get-privacy-compliance-score (retailer-id principal))
  ;; Calculate compliance score based on authorized vs unauthorized usage
  ;; This would require iteration in a real implementation
  u85 ;; Placeholder score
)
