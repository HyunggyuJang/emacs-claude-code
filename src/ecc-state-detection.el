;;; -*- coding: utf-8; lexical-binding: t -*-
;;; Author: ywatanabe
;;; Timestamp: <2025-06-04 08:47:06>
;;; File: /home/ywatanabe/.emacs.d/lisp/emacs-claude-code/src/ecc-state-detection.el

;;; Copyright (C) 2025 Yusuke Watanabe (ywatanabe@alumni.u-tokyo.ac.jp)


;; 1. Dependencies
;; ----------------------------------------
(require 'ecc-debug)
(require 'ecc-vterm-utils)

;; 2. Configuration
;; ----------------------------------------

(defcustom --ecc-state-detection-buffer-size 2048
  "Number of characters to check from end of buffer for prompt detection."
  :type 'integer
  :group 'ecc)

(defcustom --ecc-state-detection-flash-duration 0.5
  "Duration in seconds to flash the detected text."
  :type 'number
  :group 'ecc)

(defcustom --ecc-state-detection-flash-face 'highlight
  "Face to use for flashing detected text."
  :type 'face
  :group 'ecc)

;; 3. Variables
;; ----------------------------------------

(defvar --ecc-state-detection-patterns
  '((:initial-waiting . "│ > Try ")
    (:waiting . "│ >                            ")
    (:y/n . "❯ 1. Yes")
    (:y/y/n . " 2. Yes, and")
    (:running . " tokens · esc to interrupt)"))
  "Alist mapping state symbols to detection patterns. Note that space around > are non-breaking space.")

(defvar --ecc-state-detection--flash-overlays nil
  "List of overlays used for flashing detected text.")

;; 4. Main Entry Points
;; ----------------------------------------

(defun --ecc-state-detection-detect (&optional buffer)
  "Detect Claude prompt state in BUFFER or current buffer."
  (with-current-buffer (or buffer (current-buffer))
    (--ecc-debug-message "Detecting state in buffer: %s" (buffer-name))
    (let ((buffer-text (buffer-substring-no-properties
                        (max
                         (- (point-max)
                            --ecc-state-detection-buffer-size)
                         (point-min))
                        (point-max))))
      (--ecc-state-detection--analyze-text buffer-text))))

;; 5. Core Functions
;; ----------------------------------------

(defun --ecc-state-detection--analyze-text (text)
  "Analyze TEXT to detect Claude prompt state."
  (catch 'found
    ;; Check for running pattern first (highest priority)
    ;; Only consider it running if we see the tokens counter actively changing
    (let
        ((running-pattern
          (cdr (assq :running --ecc-state-detection-patterns))))
      (when
          (and running-pattern
               (string-match-p (regexp-quote running-pattern) text)
               ;; Also check for the presence of actual token count
               (string-match-p "[0-9]+ tokens · esc to interrupt)"
                               text))
        (--ecc-debug-message "Matched state :running")
        (throw 'found :running)))

    ;; Check for Y/Y/N pattern first (must come before Y/N check)
    (let
        ((yyn-pattern
          (cdr (assq :y/y/n --ecc-state-detection-patterns))))
      (when
          (and yyn-pattern
               (string-match-p (regexp-quote yyn-pattern) text))
        (--ecc-debug-message "Matched state :y/y/n")
        (throw 'found :y/y/n)))

    ;; Check for exact pattern matches
    (dolist (pattern-pair --ecc-state-detection-patterns)
      (let ((state (car pattern-pair))
            (pattern (cdr pattern-pair)))
        (when (string-match-p (regexp-quote pattern) text)
          (--ecc-debug-message "Matched state %s" state)
          (throw 'found state))))
    nil))

;; 6. Helper/Utility Functions
;; ----------------------------------------

(defun --ecc-state-detection--has-previous-messages-p ()
  "Check if buffer has previous messages (not the initial state)."
  ;; Simply check buffer size as a quick heuristic
  (> (- (point-max) (point-min)) 500))

(defun --ecc-state-detection-get-name (state)
  "Convert STATE symbol to human-readable name."
  (cond
   ((eq state :y/y/n) "Y/Y/N")
   ((eq state :y/n) "Y/N")
   ((eq state :waiting) "Continue")
   ((eq state :initial-waiting) "Initial-Waiting")
   ((eq state :running) "Running")
   (t (format "%s" state))))

(defun --ecc-state-detection-flash-pattern (state &optional buffer)
  "Flash the detected pattern for STATE in BUFFER."
  (with-current-buffer (or buffer (current-buffer))
    (let ((pattern (cdr (assq state --ecc-state-detection-patterns))))
      (when pattern
        (--ecc-state-detection--remove-flash-overlays)
        (save-excursion
          (goto-char (point-max))
          (when (search-backward pattern
                                 (max (- (point-max)
                                         --ecc-state-detection-buffer-size)
                                      (point-min))
                                 t)
            (let
                ((overlay
                  (make-overlay (match-beginning 0) (match-end 0))))
              (overlay-put overlay 'face
                           --ecc-state-detection-flash-face)
              (overlay-put overlay 'priority 1000)
              (push overlay --ecc-state-detection--flash-overlays)
              (run-with-timer --ecc-state-detection-flash-duration nil
                              '--ecc-state-detection--remove-flash-overlays))))))))

(defun --ecc-state-detection--remove-flash-overlays ()
  "Remove all flash overlays."
  (mapc 'delete-overlay --ecc-state-detection--flash-overlays)
  (setq --ecc-state-detection--flash-overlays nil))

(defun --ecc-state-detection-diagnose (&optional buffer)
  "Diagnose what Claude prompt patterns exist in BUFFER."
  (interactive)
  (with-current-buffer (or buffer (current-buffer))
    (let* ((buffer-text (buffer-substring-no-properties
                         (max
                          (- (point-max)
                             --ecc-state-detection-buffer-size)
                          (point-min))
                         (point-max)))
           (state (--ecc-state-detection-detect))
           (last-100-chars
            (substring buffer-text
                       (max 0 (- (length buffer-text) 100))))
           (last-line (--ecc-vterm-utils-get-last-non-empty-line))
           (session-active
            (--ecc-vterm-utils-is-claude-session-active)))
      (--ecc-debug-message "=== Claude State Detection Diagnosis ===")
      (--ecc-debug-message "Current state: %s" (or state "none"))
      (--ecc-debug-message "Claude session active: %s"
                           (if session-active "yes" "no"))
      (--ecc-debug-message "Last non-empty line: %S" last-line)
      (--ecc-debug-message "Last 100 chars: %S" last-100-chars)
      (--ecc-debug-message "Contains '│': %s"
                           (if (string-match-p "│" buffer-text) "yes" "no"))
      (--ecc-debug-message "Contains '>': %s"
                           (if (string-match-p ">" buffer-text) "yes" "no"))
      (--ecc-debug-message "Contains 'Human:': %s"
                           (if (string-match-p "Human:" buffer-text) "yes" "no"))
      (--ecc-debug-message "Contains 'esc to interrupt': %s"
                           (if (string-match-p "esc to interrupt" buffer-text)
                               "yes"
                             "no"))
      (--ecc-debug-message "========================================")
      state)))

(when
    (not load-file-name)
  (--ecc-debug-message "ecc-state-detection.el loaded."
                       (file-name-nondirectory
                        (or load-file-name buffer-file-name))))


(provide 'ecc-state-detection)

(when
    (not load-file-name)
  (message "ecc-state-detection.el loaded."
           (file-name-nondirectory
            (or load-file-name buffer-file-name))))