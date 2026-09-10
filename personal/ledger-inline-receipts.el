;;; ledger-inline-receipts.el --- Inline receipt PDFs in Ledger buffers -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Display a PDF named by a Ledger comment such as:
;;
;;   ; receipt: file:///home/jdamon/ZCU102_Eval.pdf
;;
;; Previews are made by `org-inline-pdf', so they use the same renderer and
;; cache as inline PDFs in Org buffers.

;;; Code:

(require 'url-parse)
(require 'url-util)

(defgroup ledger-inline-receipts nil
  "Inline receipt previews in Ledger buffers."
  :group 'ledger)

(defcustom ledger-inline-receipts-width 600
  "Width in pixels of an inline receipt preview."
  :type 'integer
  :group 'ledger-inline-receipts)

(defconst ledger-inline-receipts--regexp
  "^[ \t]*;[ \t]*receipt:[ \t]*\\(file://[^ \t\n]+\\.pdf\\)[ \t]*$")

(defvar-local ledger-inline-receipts--refresh-timer nil
  "Idle timer used to refresh receipt previews after an edit.")

(defun ledger-inline-receipts--clear ()
  "Remove receipt-preview overlays from the current buffer."
  (remove-overlays (point-min) (point-max) 'ledger-inline-receipts t))

(defun ledger-inline-receipts--file-name (url)
  "Return the local file name represented by file URL URL."
  (let ((parsed (url-generic-parse-url url)))
    (unless (member (url-host parsed) '(nil "" "localhost"))
      (user-error "Receipt URL must name a local file: %s" url))
    (url-unhex-string (url-filename parsed))))

(defun ledger-inline-receipts-refresh ()
  "Refresh inline PDF previews for `; receipt: file:///...' comments."
  (interactive)
  (ledger-inline-receipts--clear)
  ;; Enable the same advice that Org uses before calling its image creator.
  (unless (advice-member-p #'org-inline-pdf--make-preview-for-pdf
                           'org--create-inline-image)
    (org-inline-pdf-mode 1))
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward ledger-inline-receipts--regexp nil t)
      (let* ((receipt-beg (match-beginning 0))
             (receipt-end (match-end 0))
             (file (ledger-inline-receipts--file-name (match-string-no-properties 1)))
             (image (and (file-readable-p file)
                         (org--create-inline-image
                          file ledger-inline-receipts-width))))
        (when image
          ;; Attach to the receipt text itself.  Zero-width overlays do not
          ;; reliably render `after-string' display properties in every GUI.
          (let ((overlay (make-overlay receipt-beg receipt-end)))
            (overlay-put overlay 'ledger-inline-receipts t)
            (overlay-put overlay 'evaporate t)
            (overlay-put overlay 'after-string
                         (concat "\n" (propertize " " 'display image)))))))))

(defun ledger-inline-receipts--schedule-refresh (&rest _)
  "Refresh receipt previews after editing has been idle briefly."
  (when (timerp ledger-inline-receipts--refresh-timer)
    (cancel-timer ledger-inline-receipts--refresh-timer))
  (setq ledger-inline-receipts--refresh-timer
        (run-with-idle-timer
         0.25 nil
         (lambda (buffer)
           (when (buffer-live-p buffer)
             (with-current-buffer buffer
               (when ledger-inline-receipts-mode
                 (ledger-inline-receipts-refresh))))
           (when (buffer-live-p buffer)
             (with-current-buffer buffer
               (setq ledger-inline-receipts--refresh-timer nil))))
         (current-buffer))))

;;;###autoload
(define-minor-mode ledger-inline-receipts-mode
  "Display PDFs referenced by Ledger `receipt' comments inline.

This mode only operates in Ledger buffers and uses `org-inline-pdf' for PDF
rendering.  Run `ledger-inline-receipts-refresh' after editing a receipt URL."
  :init-value nil
  :lighter " RecPDF"
  (if ledger-inline-receipts-mode
      (progn
        (require 'org-inline-pdf)
        (ledger-inline-receipts-refresh)
        (add-hook 'after-change-functions
                  #'ledger-inline-receipts--schedule-refresh nil t)
        (add-hook 'after-save-hook #'ledger-inline-receipts-refresh nil t))
    (when (timerp ledger-inline-receipts--refresh-timer)
      (cancel-timer ledger-inline-receipts--refresh-timer))
    (setq ledger-inline-receipts--refresh-timer nil)
    (remove-hook 'after-change-functions
                 #'ledger-inline-receipts--schedule-refresh t)
    (remove-hook 'after-save-hook #'ledger-inline-receipts-refresh t)
    (ledger-inline-receipts--clear)))

(add-hook 'ledger-mode-hook #'ledger-inline-receipts-mode)

(provide 'ledger-inline-receipts)

;;; ledger-inline-receipts.el ends here
