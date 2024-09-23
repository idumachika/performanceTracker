;; title: Staff Performance Tracker
;; version: 1.1
;; summary: Smart contract for managing and tracking staff performance metrics.
;; description: This contract manages staff performance, tracks performance history, and supports role-based access control.

;; Define roles for role-based access control
(define-map staff-roles
  {staff-id: principal}
  {role: (string-ascii 32)})

(define-constant ROLE_ADMIN "admin")
(define-constant ROLE_MANAGER "manager")
(define-constant ROLE_STAFF "staff")

;; Performance data structure
(define-map staff-performance
  {staff-id: principal}
  { 
    productivity: uint,
    product-knowledge: uint,
    quality-of-service: uint,
    adherence-to-schedule: uint,
    discipline: uint,
    task-completion: uint,
    goal-achievement: uint,
    team-player: uint,
    performance-status: (string-ascii 32)
  })

;; Performance history for tracking past performance
(define-map performance-history
  {staff-id: principal, record-id: uint}
  { 
    productivity: uint,
    product-knowledge: uint,
    quality-of-service: uint,
    adherence-to-schedule: uint,
    discipline: uint,
    task-completion: uint,
    goal-achievement: uint,
    team-player: uint,
    performance-status: (string-ascii 32),
    date: uint
  })

(define-data-var record-counter uint u0)

;; Initialize staff performance
(define-public (initialize-performance (staff-id principal))
  (begin
    (map-set staff-performance
      {staff-id: staff-id}
      {
        productivity: u0,
        product-knowledge: u0,
        quality-of-service: u0,
        adherence-to-schedule: u0,
        discipline: u0,
        task-completion: u0,
        goal-achievement: u0,
        team-player: u0,
        performance-status: "Active"
      })
    (ok "Performance initialized for staff.")
  )
)

;; Update performance metrics and track history
(define-public (update-metrics
  (staff-id principal)
  (productivity uint)
  (product-knowledge uint)
  (quality-of-service uint)
  (adherence-to-schedule uint)
  (discipline uint)
  (task-completion uint)
  (goal-achievement uint)
  (team-player uint)
  (performance-status (string-ascii 32)))

  (begin
    ;; Update current performance
    (map-set staff-performance
      {staff-id: staff-id}
      { 
        productivity: productivity,
        product-knowledge: product-knowledge,
        quality-of-service: quality-of-service,
        adherence-to-schedule: adherence-to-schedule,
        discipline: discipline,
        task-completion: task-completion,
        goal-achievement: goal-achievement,
        team-player: team-player,
        performance-status: performance-status
      })

    ;; Log the update into performance history
    (let ((current-counter (var-get record-counter)))
      (map-insert performance-history
        {staff-id: staff-id, record-id: current-counter}
        {
          productivity: productivity,
          product-knowledge: product-knowledge,
          quality-of-service: quality-of-service,
          adherence-to-schedule: adherence-to-schedule,
          discipline: discipline,
          task-completion: task-completion,
          goal-achievement: goal-achievement,
          team-player: team-player,
          performance-status: performance-status,
          date: block-height
        })
      (var-set record-counter (+ current-counter u1))
    )
    (ok "Performance metrics updated.")
  )
)

;; Get performance information for a staff
(define-read-only (get-performance (staff-id principal))
  (match (map-get? staff-performance {staff-id: staff-id})
    some-metrics ;; variable name for the value if present
    (ok some-metrics) ;; expression if the value is found in the map
    (err "No performance metrics found for this staff.") ;; expression if the value is not found
  )
)


;; Retrieve performance history
(define-read-only (get-performance-history (staff-id principal) (record-id uint))
  (match (map-get? performance-history {staff-id: staff-id, record-id: record-id})
    some-record ;; variable name for the value if present
    (ok some-record) ;; expression if the record is found in the map
    (err "No history found for this record.") ;; expression if the record is not found
  )
)


;; Role-based access control (e.g., only managers or admins can update staff performance)
(define-public (set-role (staff-id principal) (role (string-ascii 32)))
  (begin
    (map-set staff-roles {staff-id: staff-id} {role: role})
    (ok (tuple (staff-id staff-id) (role role)))
  )
)

;; Retrieve staff role
(define-read-only (get-role (staff-id principal))
  (match (map-get? staff-roles {staff-id: staff-id})
    some-role (ok some-role)
    (err "Role not found for this staff.")
  )
)


;; Check if a user is an admin or manager
(define-read-only (is-admin-or-manager (staff-id principal))
  (let ((role (map-get? staff-roles {staff-id: staff-id})))
    (match role
      some-role
      (or (is-eq (get role some-role) ROLE_ADMIN)
          (is-eq (get role some-role) ROLE_MANAGER))
      false ;; Return false if no role is found
    )
  )
)


;; Deactivate staff performance
(define-public (deactivate-staff (staff-id principal))
  (begin
    (match (map-get? staff-performance {staff-id: staff-id})
      some-staff-data ;; The variable to hold the value if it exists
      (begin
        (map-set staff-performance
          {staff-id: staff-id}
          {productivity: (get productivity some-staff-data),
           product-knowledge: (get product-knowledge some-staff-data),
           quality-of-service: (get quality-of-service some-staff-data),
           adherence-to-schedule: (get adherence-to-schedule some-staff-data),
           discipline: (get discipline some-staff-data),
           task-completion: (get task-completion some-staff-data),
           goal-achievement: (get goal-achievement some-staff-data),
           team-player: (get team-player some-staff-data),
           performance-status: "Inactive"})
        (ok "Staff deactivated.")
      )
      (err "No performance metrics found for this staff.") ;; Return an error if no staff data is found
    )
  )
)

