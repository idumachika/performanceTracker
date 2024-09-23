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
(define-constant WITHDRAWAL_COOLDOWN u144) 

;; Liquidity pool for tracking staff deposits
(define-map liquidity-pool
  {staff-id: principal}
  {total-liquidity: uint})

;; New map to track last withdrawal timestamp for each staff member
(define-map last-withdrawal
  {staff-id: principal}
  {block-height: uint})

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

;; Deposit liquidity into the protocol
(define-public (deposit-liquidity (staff-id principal) (amount uint))
  (begin
    (if (is-authorized tx-sender)
      (if (and (> amount MIN_DEPOSIT_PER_TX) (<= amount MAX_DEPOSIT_PER_TX))
        (begin
          ;; Transfer STX to the contract
          (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
          ;; Update the staff's liquidity balance
          (let ((existing-liquidity (default-to u0 (get total-liquidity (map-get? liquidity-pool {staff-id: staff-id})))))
            (map-set liquidity-pool
              {staff-id: staff-id}
              {total-liquidity: (+ existing-liquidity amount)}))
          ;; Log the deposit in history
          (let ((current-counter (var-get deposit-counter)))
            (map-insert deposit-history
              {staff-id: staff-id, deposit-id: current-counter}
              {amount: amount, deposited-by: tx-sender, date: block-height})
            (var-set deposit-counter (+ current-counter u1)))
          ;; Return success message
          (ok {message: "Liquidity deposited successfully.", status: "success"})
        )
        ;; Return an error for invalid deposit amount
        (err u1)
      )
      ;; Return an error for unauthorized access
      (err u2)
    )
  )
)
;; Retrieve liquidity balance for a staff
(define-read-only (get-liquidity (staff-id principal))
  (match (map-get? liquidity-pool {staff-id: staff-id})
    some-liquidity
    (ok (get total-liquidity some-liquidity))
    (ok u0) ;; If no liquidity is found, return 0
  )
)

;; Retrieve deposit history
(define-read-only (get-deposit-history (staff-id principal) (deposit-id uint))
  (match (map-get? deposit-history {staff-id: staff-id, deposit-id: deposit-id})
    some-deposit
    (ok some-deposit)
    (err "No deposit record found.")
  )
)

;; Reward staff based on liquidity deposits
(define-public (reward-staff (staff-id principal))
  (let ((liquidity (default-to u0 (get total-liquidity (map-get? liquidity-pool {staff-id: staff-id})))))
    (if (> liquidity u0)
      (begin
        ;; Logic for rewarding the staff based on their liquidity (e.g., distribute tokens)
        ;; Example: Send tokens based on liquidity balance
        (ok (tuple (staff-id staff-id) (reward (+ liquidity u100))))
      )
      (err "Staff has no liquidity to reward.")
    )
  )
)

;; Withdraw liquidity from the protocol
(define-public (withdraw-liquidity (amount uint))
  (let (
    (staff-id tx-sender)
    (current-liquidity (default-to u0 (get total-liquidity (map-get? liquidity-pool {staff-id: staff-id}))))
    (last-withdrawal-height (default-to u0 (get block-height (map-get? last-withdrawal {staff-id: staff-id}))))
  )
    (if (and 
         (<= amount current-liquidity)
         (>= amount MIN_DEPOSIT_PER_TX)
         (<= amount MAX_DEPOSIT_PER_TX)
         (> (- block-height last-withdrawal-height) WITHDRAWAL_COOLDOWN))
      (begin
        ;; Transfer STX from the contract to the staff member
        (try! (as-contract (stx-transfer? amount (as-contract tx-sender) staff-id)))
        ;; Update the staff's liquidity balance
        (map-set liquidity-pool
          {staff-id: staff-id}
          {total-liquidity: (- current-liquidity amount)})
        ;; Update the last withdrawal timestamp
        (map-set last-withdrawal
          {staff-id: staff-id}
          {block-height: block-height})
        ;; Log the withdrawal in history
        (let ((current-counter (var-get deposit-counter)))
          (map-insert deposit-history
            {staff-id: staff-id, deposit-id: current-counter}
            {amount: (- u0 amount), deposited-by: tx-sender, date: block-height})
          (var-set deposit-counter (+ current-counter u1)))
        ;; Return success message
        (ok {message: "Liquidity withdrawn successfully.", status: "success"})
      )
      ;; Return an error for invalid withdrawal conditions
      (err u3)
    )
  )
)

;; Get time until next allowed withdrawal
(define-read-only (time-to-next-withdrawal (staff-id principal))
  (let (
    (last-withdrawal-height (default-to u0 (get block-height (map-get? last-withdrawal {staff-id: staff-id}))))
    (blocks-since-last-withdrawal (- block-height last-withdrawal-height))
  )
    (if (>= blocks-since-last-withdrawal WITHDRAWAL_COOLDOWN)
      (ok u0)
      (ok (- WITHDRAWAL_COOLDOWN blocks-since-last-withdrawal))
    )
  )
)

;; Get withdrawal info
(define-read-only (get-withdrawal-info (staff-id principal))
  (let (
    (current-liquidity (default-to u0 (get total-liquidity (map-get? liquidity-pool {staff-id: staff-id}))))
    (last-withdrawal-height (default-to u0 (get block-height (map-get? last-withdrawal {staff-id: staff-id}))))
    (blocks-since-last-withdrawal (- block-height last-withdrawal-height))
  )
    (ok {
      available-balance: current-liquidity,
      cooldown-blocks-remaining: (if (>= blocks-since-last-withdrawal WITHDRAWAL_COOLDOWN)
                                    u0
                                    (- WITHDRAWAL_COOLDOWN blocks-since-last-withdrawal)),
      min-withdrawal: MIN_DEPOSIT_PER_TX,
      max-withdrawal: (min MAX_DEPOSIT_PER_TX current-liquidity)
    })
  )
)



