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