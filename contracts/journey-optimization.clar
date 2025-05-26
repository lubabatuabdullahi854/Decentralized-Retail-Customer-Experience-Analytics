;; Journey Optimization Contract
;; Analyzes and optimizes customer experience journeys

(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INVALID_PARAMETERS (err u401))
(define-constant ERR_NOT_FOUND (err u402))

;; Journey stage definitions
(define-constant STAGE_AWARENESS u1)
(define-constant STAGE_CONSIDERATION u2)
(define-constant STAGE_PURCHASE u3)
(define-constant STAGE_RETENTION u4)
(define-constant STAGE_ADVOCACY u5)

;; Data structures
(define-map journey-analytics
  { retailer-id: principal, stage: uint }
  {
    total-customers: uint,
    conversion-rate: uint,
    average-time: uint,
    drop-off-rate: uint,
    optimization-score: uint,
    last-updated: uint
  }
)

(define-map optimization-recommendations
  { recommendation-id: uint }
  {
    retailer-id: principal,
    stage: uint,
    recommendation-type: uint,
    priority: uint,
    impact-score: uint,
    implementation-effort: uint,
    created-at: uint,
    status: uint
  }
)

(define-map customer-touchpoints
  { customer-id: principal, retailer-id: principal, touchpoint-id: uint }
  {
    stage: uint,
    interaction-type: uint,
    timestamp: uint,
    duration: uint,
    success: bool,
    satisfaction-score: uint
  }
)

(define-data-var next-recommendation-id uint u1)
(define-data-var next-touchpoint-id uint u1)

;; Public functions
(define-public (record-touchpoint
  (retailer-id principal)
  (stage uint)
  (interaction-type uint)
  (duration uint)
  (success bool)
  (satisfaction-score uint))
  (let ((touchpoint-id (var-get next-touchpoint-id)))
    (asserts! (<= stage u5) ERR_INVALID_PARAMETERS)
    (asserts! (> stage u0) ERR_INVALID_PARAMETERS)
    (asserts! (<= satisfaction-score u5) ERR_INVALID_PARAMETERS)

    (map-set customer-touchpoints
      { customer-id: tx-sender, retailer-id: retailer-id, touchpoint-id: touchpoint-id }
      {
        stage: stage,
        interaction-type: interaction-type,
        timestamp: block-height,
        duration: duration,
        success: success,
        satisfaction-score: satisfaction-score
      }
    )

    ;; Update journey analytics
    (update-journey-analytics retailer-id stage success satisfaction-score)

    (var-set next-touchpoint-id (+ touchpoint-id u1))
    (ok touchpoint-id)
  )
)

(define-private (update-journey-analytics (retailer-id principal) (stage uint) (success bool) (satisfaction uint))
  (match (map-get? journey-analytics { retailer-id: retailer-id, stage: stage })
    existing-analytics
    (let (
      (total-customers (+ (get total-customers existing-analytics) u1))
      (current-conversion (get conversion-rate existing-analytics))
      (success-count (if success (+ u1 (/ (* current-conversion (get total-customers existing-analytics)) u100)) (/ (* current-conversion (get total-customers existing-analytics)) u100)))
      (new-conversion-rate (/ (* success-count u100) total-customers))
      (optimization-score (calculate-optimization-score new-conversion-rate satisfaction))
    )
      (map-set journey-analytics
        { retailer-id: retailer-id, stage: stage }
        {
          total-customers: total-customers,
          conversion-rate: new-conversion-rate,
          average-time: (get average-time existing-analytics), ;; Simplified
          drop-off-rate: (- u100 new-conversion-rate),
          optimization-score: optimization-score,
          last-updated: block-height
        }
      )
    )
    ;; First entry for this stage
    (map-set journey-analytics
      { retailer-id: retailer-id, stage: stage }
      {
        total-customers: u1,
        conversion-rate: (if success u100 u0),
        average-time: u0,
        drop-off-rate: (if success u0 u100),
        optimization-score: (calculate-optimization-score (if success u100 u0) satisfaction),
        last-updated: block-height
      }
    )
  )
)

(define-private (calculate-optimization-score (conversion-rate uint) (satisfaction uint))
  (/ (+ (* conversion-rate u60) (* satisfaction u20)) u100)
)

(define-public (generate-optimization-recommendation
  (retailer-id principal)
  (stage uint)
  (recommendation-type uint)
  (priority uint))
  (let ((recommendation-id (var-get next-recommendation-id)))
    (asserts! (<= stage u5) ERR_INVALID_PARAMETERS)
    (asserts! (> stage u0) ERR_INVALID_PARAMETERS)
    (asserts! (<= priority u3) ERR_INVALID_PARAMETERS)

    (map-set optimization-recommendations
      { recommendation-id: recommendation-id }
      {
        retailer-id: retailer-id,
        stage: stage,
        recommendation-type: recommendation-type,
        priority: priority,
        impact-score: (calculate-impact-score stage recommendation-type),
        implementation-effort: (calculate-effort-score recommendation-type),
        created-at: block-height,
        status: u1 ;; Pending
      }
    )

    (var-set next-recommendation-id (+ recommendation-id u1))
    (ok recommendation-id)
  )
)

(define-private (calculate-impact-score (stage uint) (rec-type uint))
  ;; Simplified impact calculation
  (+ (* stage u10) (* rec-type u5))
)

(define-private (calculate-effort-score (rec-type uint))
  ;; Simplified effort calculation
  (* rec-type u15)
)

;; Read-only functions
(define-read-only (get-journey-analytics (retailer-id principal) (stage uint))
  (map-get? journey-analytics { retailer-id: retailer-id, stage: stage })
)

(define-read-only (get-optimization-recommendation (recommendation-id uint))
  (map-get? optimization-recommendations { recommendation-id: recommendation-id })
)

(define-read-only (get-customer-touchpoint (customer-id principal) (retailer-id principal) (touchpoint-id uint))
  (map-get? customer-touchpoints { customer-id: customer-id, retailer-id: retailer-id, touchpoint-id: touchpoint-id })
)

(define-read-only (calculate-journey-health (retailer-id principal))
  ;; Calculate overall journey health across all stages
  (let (
    (stage1 (default-to { conversion-rate: u0, optimization-score: u0 } (map-get? journey-analytics { retailer-id: retailer-id, stage: u1 })))
    (stage2 (default-to { conversion-rate: u0, optimization-score: u0 } (map-get? journey-analytics { retailer-id: retailer-id, stage: u2 })))
    (stage3 (default-to { conversion-rate: u0, optimization-score: u0 } (map-get? journey-analytics { retailer-id: retailer-id, stage: u3 })))
  )
    (/ (+ (get optimization-score stage1) (get optimization-score stage2) (get optimization-score stage3)) u3)
  )
)
