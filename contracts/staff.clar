;; Title: Liquidity Deposit and Reward Protocol
;; Version: 1.1
;; Summary: Smart contract for managing liquidity deposits and rewarding staff.
;; Description: This contract allows authorized personnel to deposit liquidity into the protocol and reward staff based on their liquidity balance.

;; Define roles for role-based access control
(define-map staff-roles
  {staff-id: principal}
  {role: (string-ascii 32)})

(define-constant ROLE_ADMIN "admin")
(define-constant ROLE_MANAGER "manager")
(define-constant ROLE_HR "HR")

;; Liquidity pool for tracking staff deposits
(define-map liquidity-pool
  {staff-id: principal}
  {total-liquidity: uint})

;; Deposit history for auditing liquidity deposits
(define-map deposit-history
  {staff-id: principal, deposit-id: uint}
  {amount: uint, deposited-by: principal, date: uint})

(define-data-var deposit-counter uint u0)

;; Deposit limits
(define-constant MAX_DEPOSIT_PER_TX u10000) ;; Maximum allowed deposit per transaction
(define-constant MIN_DEPOSIT_PER_TX u100)   ;; Minimum allowed deposit per transaction

;; Role-based access control (e.g., only HR/Admin/Manager can deposit liquidity)
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

;; Check if a user is an admin, HR, or manager
(define-read-only (is-authorized (staff-id principal))
  (let ((role (map-get? staff-roles {staff-id: staff-id})))
    (match role
      some-role
      (or (is-eq (get role some-role) ROLE_ADMIN)
          (is-eq (get role some-role) ROLE_HR)
          (is-eq (get role some-role) ROLE_MANAGER))
      false ;; Return false if no valid role is found
    )
  )
)


