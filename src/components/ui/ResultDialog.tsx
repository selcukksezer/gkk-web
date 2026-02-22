// ============================================================
// ResultDialog — İşlem sonucu diyalogu
// ============================================================

"use client";

import { Modal } from "@/components/ui/Modal";
import { Button } from "@/components/ui/Button";

interface ResultDialogProps {
  open: boolean;
  title: string;
  message: string;
  success?: boolean;
  onClose: () => void;
}

export function ResultDialog({ open, title, message, success = true, onClose }: ResultDialogProps) {
  return (
    <Modal isOpen={open} onClose={onClose} title={title}>
      <div className="flex flex-col items-center gap-3 py-2">
        <span className="text-5xl">{success ? "✅" : "❌"}</span>
        <p className="text-sm text-center text-[var(--text-secondary)]">{message}</p>
      </div>
      <div className="flex justify-center mt-4">
        <Button variant="primary" onClick={onClose}>
          Tamam
        </Button>
      </div>
    </Modal>
  );
}
