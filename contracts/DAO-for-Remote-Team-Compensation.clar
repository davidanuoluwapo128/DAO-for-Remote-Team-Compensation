(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-not-member (err u101))
(define-constant err-task-not-found (err u102))
(define-constant err-already-voted (err u103))
(define-constant err-voting-closed (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-invalid-amount (err u106))
(define-constant err-task-already-executed (err u107))
(define-constant err-minimum-approval-not-met (err u108))

(define-data-var total-members uint u0)
(define-data-var treasury-balance uint u0)
(define-data-var task-counter uint u0)
(define-data-var minimum-approval-percentage uint u60)

(define-map members principal {
    voting-power: uint,
    joined-at: uint,
    total-earnings: uint,
    is-active: bool
})

(define-map tasks uint {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    compensation: uint,
    task-type: (string-ascii 50),
    duration: uint,
    complexity: uint,
    created-at: uint,
    voting-deadline: uint,
    is-executed: bool,
    yes-votes: uint,
    no-votes: uint
})

(define-map task-votes {task-id: uint, voter: principal} bool)

(define-map member-contributions principal {
    tasks-completed: uint,
    total-compensation: uint,
    average-rating: uint,
    last-active: uint
})

(define-public (initialize-dao)
    (begin
        (try! (add-member contract-owner u100))
        (var-set treasury-balance u0)
        (ok true)
    )
)

(define-public (add-member (new-member principal) (voting-power uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (> voting-power u0) err-invalid-amount)
        (map-set members new-member {
            voting-power: voting-power,
            joined-at: stacks-block-height,
            total-earnings: u0,
            is-active: true
        })
        (var-set total-members (+ (var-get total-members) u1))
        (ok true)
    )
)

(define-public (remove-member (member principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (match (map-get? members member)
            member-data (begin
                (map-set members member (merge member-data {is-active: false}))
                (var-set total-members (- (var-get total-members) u1))
                (ok true)
            )
            err-not-member
        )
    )
)

(define-public (deposit-to-treasury (amount uint))
    (begin
        (asserts! (> amount u0) err-invalid-amount)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set treasury-balance (+ (var-get treasury-balance) amount))
        (ok true)
    )
)

(define-public (submit-task 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (compensation uint)
    (task-type (string-ascii 50))
    (duration uint)
    (complexity uint)
    (voting-duration uint)
)
    (let (
        (task-id (+ (var-get task-counter) u1))
        (deadline (+ stacks-block-height voting-duration))
        (member-data (unwrap! (map-get? members tx-sender) err-not-member))
    )
        (asserts! (get is-active member-data) err-not-member)
        (asserts! (> compensation u0) err-invalid-amount)
        (asserts! (<= compensation (var-get treasury-balance)) err-insufficient-funds)
        (map-set tasks task-id {
            creator: tx-sender,
            title: title,
            description: description,
            compensation: compensation,
            task-type: task-type,
            duration: duration,
            complexity: complexity,
            created-at: stacks-block-height,
            voting-deadline: deadline,
            is-executed: false,
            yes-votes: u0,
            no-votes: u0
        })
        (var-set task-counter task-id)
        (ok task-id)
    )
)

(define-public (vote-on-task (task-id uint) (vote bool))
    (let (
        (task-data (unwrap! (map-get? tasks task-id) err-task-not-found))
        (member-data (unwrap! (map-get? members tx-sender) err-not-member))
        (vote-key {task-id: task-id, voter: tx-sender})
    )
        (asserts! (get is-active member-data) err-not-member)
        (asserts! (<= stacks-block-height (get voting-deadline task-data)) err-voting-closed)
        (asserts! (is-none (map-get? task-votes vote-key)) err-already-voted)
        (asserts! (not (get is-executed task-data)) err-task-already-executed)
        
        (map-set task-votes vote-key vote)
        
        (if vote
            (map-set tasks task-id (merge task-data {
                yes-votes: (+ (get yes-votes task-data) (get voting-power member-data))
            }))
            (map-set tasks task-id (merge task-data {
                no-votes: (+ (get no-votes task-data) (get voting-power member-data))
            }))
        )
        (ok true)
    )
)

(define-public (execute-task (task-id uint))
    (let (
        (task-data (unwrap! (map-get? tasks task-id) err-task-not-found))
        (total-votes (+ (get yes-votes task-data) (get no-votes task-data)))
        (approval-rate (if (> total-votes u0) 
            (* (/ (get yes-votes task-data) total-votes) u100) 
            u0))
        (creator (get creator task-data))
        (compensation (get compensation task-data))
    )
        (asserts! (> stacks-block-height (get voting-deadline task-data)) err-voting-closed)
        (asserts! (not (get is-executed task-data)) err-task-already-executed)
        (asserts! (>= approval-rate (var-get minimum-approval-percentage)) err-minimum-approval-not-met)
        (asserts! (>= (var-get treasury-balance) compensation) err-insufficient-funds)
        
        (try! (as-contract (stx-transfer? compensation tx-sender creator)))
        (var-set treasury-balance (- (var-get treasury-balance) compensation))
        
        (map-set tasks task-id (merge task-data {is-executed: true}))
        
        (match (map-get? members creator)
            member-data (map-set members creator (merge member-data {
                total-earnings: (+ (get total-earnings member-data) compensation)
            }))
            false
        )
        
        (match (map-get? member-contributions creator)
            contrib-data (map-set member-contributions creator (merge contrib-data {
                tasks-completed: (+ (get tasks-completed contrib-data) u1),
                total-compensation: (+ (get total-compensation contrib-data) compensation),
                last-active: stacks-block-height
            }))
            (map-set member-contributions creator {
                tasks-completed: u1,
                total-compensation: compensation,
                average-rating: (get complexity task-data),
                last-active: stacks-block-height
            })
        )
        (ok true)
    )
)

(define-public (update-minimum-approval (new-percentage uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (and (>= new-percentage u1) (<= new-percentage u100)) err-invalid-amount)
        (var-set minimum-approval-percentage new-percentage)
        (ok true)
    )
)

(define-public (emergency-withdraw (amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (<= amount (var-get treasury-balance)) err-insufficient-funds)
        (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
        (var-set treasury-balance (- (var-get treasury-balance) amount))
        (ok true)
    )
)

(define-read-only (get-member (member principal))
    (map-get? members member)
)

(define-read-only (get-task (task-id uint))
    (map-get? tasks task-id)
)

(define-read-only (get-task-vote (task-id uint) (voter principal))
    (map-get? task-votes {task-id: task-id, voter: voter})
)

(define-read-only (get-member-contributions (member principal))
    (map-get? member-contributions member)
)

(define-read-only (get-treasury-balance)
    (var-get treasury-balance)
)

(define-read-only (get-total-members)
    (var-get total-members)
)

(define-read-only (get-task-counter)
    (var-get task-counter)
)

(define-read-only (get-minimum-approval-percentage)
    (var-get minimum-approval-percentage)
)

(define-read-only (is-task-approved (task-id uint))
    (match (map-get? tasks task-id)
        task-data (let (
            (total-votes (+ (get yes-votes task-data) (get no-votes task-data)))
            (approval-rate (if (> total-votes u0) 
                (* (/ (get yes-votes task-data) total-votes) u100) 
                u0))
        )
            (>= approval-rate (var-get minimum-approval-percentage))
        )
        false
    )
)

(define-read-only (get-voting-status (task-id uint))
    (match (map-get? tasks task-id)
        task-data {
            yes-votes: (get yes-votes task-data),
            no-votes: (get no-votes task-data),
            voting-active: (<= stacks-block-height (get voting-deadline task-data)),
            is-executed: (get is-executed task-data)
        }
        {yes-votes: u0, no-votes: u0, voting-active: false, is-executed: false}
    )
)

(define-read-only (calculate-member-reputation (member principal))
    (match (map-get? member-contributions member)
        contrib-data (let (
            (tasks-completed (get tasks-completed contrib-data))
            (avg-rating (get average-rating contrib-data))
        )
            (if (> tasks-completed u0)
                (+ (* tasks-completed u10) (* avg-rating u5))
                u0
            )
        )
        u0
    )
)
