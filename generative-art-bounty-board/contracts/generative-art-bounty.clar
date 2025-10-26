;; Generative Art Bounty Board
;; Protocol for AI generative art bounties with automated winner selection

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u600))
(define-constant err-not-found (err u601))
(define-constant err-bounty-closed (err u602))
(define-constant err-invalid-amount (err u603))
(define-constant err-unauthorized (err u604))
(define-constant err-already-selected (err u605))

;; Data Variables
(define-data-var bounty-count uint u0)
(define-data-var submission-count uint u0)
(define-data-var nonce uint u0)

;; Data Maps
(define-map bounties uint
  {
    creator: principal,
    theme: (string-ascii 100),
    description: (string-ascii 200),
    reward: uint,
    deadline: uint,
    winner-selected: bool,
    selection-method: (string-ascii 20),
    created-at: uint
  }
)

(define-map submissions uint
  {
    bounty-id: uint,
    artist: principal,
    artwork-hash: (buff 32),
    is-winner: bool,
    submitted-at: uint
  }
)

(define-map bounty-submissions {bounty-id: uint} (list 100 uint))

(define-map artist-wins principal uint)

(define-map submission-votes {submission-id: uint, voter: principal} uint)

(define-map submission-total-votes uint {vote-count: uint, total-rating: uint})

(define-map artist-reputation principal {total-submissions: uint, total-votes: uint, average-rating: uint})

(define-map bounty-categories uint (string-ascii 50))

(define-map user-feedback {submission-id: uint, reviewer: principal} (string-ascii 200))

(define-map bounty-sponsors {bounty-id: uint, sponsor: principal} uint)

;; Read-only functions
(define-read-only (get-bounty (bounty-id uint))
  (map-get? bounties bounty-id)
)

(define-read-only (get-submission (submission-id uint))
  (map-get? submissions submission-id)
)

(define-read-only (get-bounty-submissions (bounty-id uint))
  (default-to (list) (map-get? bounty-submissions {bounty-id: bounty-id}))
)

(define-read-only (get-artist-wins (artist principal))
  (default-to u0 (map-get? artist-wins artist))
)

(define-read-only (get-bounty-count)
  (ok (var-get bounty-count))
)

(define-read-only (get-submission-count)
  (ok (var-get submission-count))
)

(define-read-only (get-submission-votes (submission-id uint))
  (default-to {vote-count: u0, total-rating: u0} (map-get? submission-total-votes submission-id))
)

(define-read-only (get-user-vote (submission-id uint) (voter principal))
  (map-get? submission-votes {submission-id: submission-id, voter: voter})
)

(define-read-only (get-artist-reputation (artist principal))
  (default-to {total-submissions: u0, total-votes: u0, average-rating: u0} (map-get? artist-reputation artist))
)

(define-read-only (get-bounty-category (bounty-id uint))
  (map-get? bounty-categories bounty-id)
)

(define-read-only (get-user-feedback-for-submission (submission-id uint) (reviewer principal))
  (map-get? user-feedback {submission-id: submission-id, reviewer: reviewer})
)

(define-read-only (get-bounty-sponsor-amount (bounty-id uint) (sponsor principal))
  (default-to u0 (map-get? bounty-sponsors {bounty-id: bounty-id, sponsor: sponsor}))
)

(define-read-only (is-bounty-active (bounty-id uint))
  (match (map-get? bounties bounty-id)
    bounty (ok (and (< stacks-block-height (get deadline bounty)) (not (get winner-selected bounty))))
    (err err-not-found)
  )
)

;; Private functions
(define-private (pseudo-random (max-value uint))
  (let
    (
      (current-nonce (var-get nonce))
      (random-seed (+ (+ stacks-block-height current-nonce) stacks-block-height))
    )
    (var-set nonce (+ current-nonce u1))
    (mod random-seed max-value)
  )
)

(define-private (update-artist-reputation (artist principal) (rating uint))
  (let
    (
      (current-rep (get-artist-reputation artist))
      (new-total-votes (+ (get total-votes current-rep) u1))
      (new-total-rating (+ (* (get average-rating current-rep) (get total-votes current-rep)) rating))
      (new-average (/ new-total-rating new-total-votes))
    )
    (map-set artist-reputation artist
      {
        total-submissions: (get total-submissions current-rep),
        total-votes: new-total-votes,
        average-rating: new-average
      }
    )
    (ok true)
  )
)

;; Public functions
;; #[allow(unchecked_data)]
(define-public (create-bounty (theme (string-ascii 100)) (description (string-ascii 200)) (reward uint) (deadline uint) (selection-method (string-ascii 20)))
  (let
    (
      (bounty-id (var-get bounty-count))
    )
    (asserts! (> reward u0) err-invalid-amount)
    (asserts! (> deadline stacks-block-height) err-invalid-amount)
    (map-set bounties bounty-id
      {
        creator: tx-sender,
        theme: theme,
        description: description,
        reward: reward,
        deadline: deadline,
        winner-selected: false,
        selection-method: selection-method,
        created-at: stacks-block-height
      }
    )
    (map-set bounty-submissions {bounty-id: bounty-id} (list))
    (var-set bounty-count (+ bounty-id u1))
    (ok bounty-id)
  )
)

;; #[allow(unchecked_data)]
(define-public (submit-artwork (bounty-id uint) (artwork-hash (buff 32)))
  (let
    (
      (bounty-data (unwrap! (map-get? bounties bounty-id) err-not-found))
      (submission-id (var-get submission-count))
      (current-submissions (get-bounty-submissions bounty-id))
    )
    (asserts! (< stacks-block-height (get deadline bounty-data)) err-bounty-closed)
    (asserts! (not (get winner-selected bounty-data)) err-bounty-closed)
    (map-set submissions submission-id
      {
        bounty-id: bounty-id,
        artist: tx-sender,
        artwork-hash: artwork-hash,
        is-winner: false,
        submitted-at: stacks-block-height
      }
    )
    (map-set bounty-submissions {bounty-id: bounty-id}
      (unwrap-panic (as-max-len? (append current-submissions submission-id) u100))
    )
    (var-set submission-count (+ submission-id u1))
    (ok submission-id)
  )
)

(define-public (select-winner-random (bounty-id uint))
  (let
    (
      (bounty-data (unwrap! (map-get? bounties bounty-id) err-not-found))
      (submission-list (get-bounty-submissions bounty-id))
      (submission-count-for-bounty (len submission-list))
    )
    (asserts! (is-eq tx-sender (get creator bounty-data)) err-unauthorized)
    (asserts! (>= stacks-block-height (get deadline bounty-data)) err-bounty-closed)
    (asserts! (not (get winner-selected bounty-data)) err-already-selected)
    (asserts! (> submission-count-for-bounty u0) err-not-found)
    (let
      (
        (random-index (pseudo-random submission-count-for-bounty))
        (winner-submission-id (unwrap-panic (element-at submission-list random-index)))
        (winner-submission (unwrap-panic (map-get? submissions winner-submission-id)))
        (winner-artist (get artist winner-submission))
        (current-wins (get-artist-wins winner-artist))
      )
      (map-set submissions winner-submission-id
        (merge winner-submission { is-winner: true })
      )
      (map-set bounties bounty-id
        (merge bounty-data { winner-selected: true })
      )
      (map-set artist-wins winner-artist (+ current-wins u1))
      (ok winner-submission-id)
    )
  )
)

(define-public (select-winner-manual (bounty-id uint) (submission-id uint))
  (let
    (
      (bounty-data (unwrap! (map-get? bounties bounty-id) err-not-found))
      (submission-data (unwrap! (map-get? submissions submission-id) err-not-found))
      (winner-artist (get artist submission-data))
      (current-wins (get-artist-wins winner-artist))
    )
    (asserts! (is-eq tx-sender (get creator bounty-data)) err-unauthorized)
    (asserts! (>= stacks-block-height (get deadline bounty-data)) err-bounty-closed)
    (asserts! (not (get winner-selected bounty-data)) err-already-selected)
    (asserts! (is-eq (get bounty-id submission-data) bounty-id) err-not-found)
    (map-set submissions submission-id
      (merge submission-data { is-winner: true })
    )
    (map-set bounties bounty-id
      (merge bounty-data { winner-selected: true })
    )
    (map-set artist-wins winner-artist (+ current-wins u1))
    (ok submission-id)
  )
)

;; #[allow(unchecked_data)]
(define-public (vote-on-submission (submission-id uint) (rating uint))
  (let
    (
      (submission-data (unwrap! (map-get? submissions submission-id) err-not-found))
      (bounty-data (unwrap! (map-get? bounties (get bounty-id submission-data)) err-not-found))
      (current-votes (get-submission-votes submission-id))
      (artist (get artist submission-data))
    )
    (asserts! (<= rating u10) err-invalid-amount)
    (asserts! (>= rating u1) err-invalid-amount)
    (asserts! (< stacks-block-height (get deadline bounty-data)) err-bounty-closed)
    (asserts! (not (is-eq tx-sender artist)) err-unauthorized)
    (map-set submission-votes {submission-id: submission-id, voter: tx-sender} rating)
    (map-set submission-total-votes submission-id
      {
        vote-count: (+ (get vote-count current-votes) u1),
        total-rating: (+ (get total-rating current-votes) rating)
      }
    )
    (unwrap-panic (update-artist-reputation artist rating))
    (ok true)
  )
)

;; #[allow(unchecked_data)]
(define-public (add-bounty-category (bounty-id uint) (category (string-ascii 50)))
  (let
    (
      (bounty-data (unwrap! (map-get? bounties bounty-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get creator bounty-data)) err-unauthorized)
    (map-set bounty-categories bounty-id category)
    (ok true)
  )
)

;; #[allow(unchecked_data)]
(define-public (add-feedback (submission-id uint) (feedback (string-ascii 200)))
  (let
    (
      (submission-data (unwrap! (map-get? submissions submission-id) err-not-found))
    )
    (map-set user-feedback {submission-id: submission-id, reviewer: tx-sender} feedback)
    (ok true)
  )
)

(define-public (sponsor-bounty (bounty-id uint) (amount uint))
  (let
    (
      (bounty-data (unwrap! (map-get? bounties bounty-id) err-not-found))
      (current-sponsorship (get-bounty-sponsor-amount bounty-id tx-sender))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (not (get winner-selected bounty-data)) err-bounty-closed)
    (map-set bounty-sponsors {bounty-id: bounty-id, sponsor: tx-sender} (+ current-sponsorship amount))
    (ok true)
  )
)

(define-public (cancel-bounty (bounty-id uint))
  (let
    (
      (bounty-data (unwrap! (map-get? bounties bounty-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get creator bounty-data)) err-unauthorized)
    (asserts! (not (get winner-selected bounty-data)) err-already-selected)
    (map-set bounties bounty-id
      (merge bounty-data { winner-selected: true })
    )
    (ok true)
  )
)

(define-public (extend-bounty-deadline (bounty-id uint) (new-deadline uint))
  (let
    (
      (bounty-data (unwrap! (map-get? bounties bounty-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get creator bounty-data)) err-unauthorized)
    (asserts! (not (get winner-selected bounty-data)) err-already-selected)
    (asserts! (> new-deadline (get deadline bounty-data)) err-invalid-amount)
    (map-set bounties bounty-id
      (merge bounty-data { deadline: new-deadline })
    )
    (ok true)
  )
)

(define-public (update-bounty-reward (bounty-id uint) (new-reward uint))
  (let
    (
      (bounty-data (unwrap! (map-get? bounties bounty-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get creator bounty-data)) err-unauthorized)
    (asserts! (not (get winner-selected bounty-data)) err-already-selected)
    (asserts! (> new-reward u0) err-invalid-amount)
    (map-set bounties bounty-id
      (merge bounty-data { reward: new-reward })
    )
    (ok true)
  )
)