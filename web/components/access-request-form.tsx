"use client";

import { FormEvent, useState } from "react";
import {
  DEVICE_OPTIONS,
  FIELD_LIMITS,
  normalizeAccessRequestPayload,
  validateAccessRequest,
  type AccessRequestErrors,
  type AccessRequestInput
} from "@/lib/access-requests";

type SubmissionState =
  | { status: "idle" }
  | { status: "submitting" }
  | { status: "success"; email: string; requestId: string }
  | { status: "error"; message: string };

const initialForm: AccessRequestInput = {
  name: "",
  email: "",
  device: "",
  company: "",
  startedAt: ""
};

function createEmptyForm(): AccessRequestInput {
  return {
    ...initialForm,
    startedAt: new Date().toISOString()
  };
}

export function AccessRequestForm() {
  const [form, setForm] = useState<AccessRequestInput>(() => createEmptyForm());
  const [errors, setErrors] = useState<AccessRequestErrors>({});
  const [submission, setSubmission] = useState<SubmissionState>({ status: "idle" });

  const isSubmitting = submission.status === "submitting";

  function updateField(field: keyof AccessRequestInput, value: string) {
    setForm((current) => ({ ...current, [field]: value }));
    setErrors((current) => ({ ...current, [field]: undefined }));
    if (submission.status === "error") {
      setSubmission({ status: "idle" });
    }
  }

  async function submitRequest(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const normalized = normalizeAccessRequestPayload(form);
    const validation = validateAccessRequest(normalized);

    if (!validation.ok) {
      setErrors(validation.errors);
      setSubmission({ status: "idle" });
      return;
    }

    setSubmission({ status: "submitting" });

    try {
      const response = await fetch("/api/access-requests", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(normalized)
      });
      const result = (await response.json()) as {
        errors?: AccessRequestErrors;
        id?: string;
        message?: string;
      };

      if (!response.ok) {
        if (result.errors) {
          setErrors(result.errors);
        }
        throw new Error(result.message ?? "Unable to submit your request.");
      }

      setErrors({});
      setSubmission({
        status: "success",
        email: validation.value.email,
        requestId: result.id ?? ""
      });
      setForm(createEmptyForm());
    } catch (error) {
      setSubmission({
        status: "error",
        message: error instanceof Error ? error.message : "Unable to submit your request."
      });
    }
  }

  return (
    <form className="access-form" onSubmit={submitRequest} noValidate>
      <div className="field-group">
        <label htmlFor="name">Name</label>
        <input
          id="name"
          name="name"
          type="text"
          autoComplete="name"
          maxLength={FIELD_LIMITS.name}
          value={form.name}
          onChange={(event) => updateField("name", event.target.value)}
          aria-invalid={Boolean(errors.name)}
          aria-describedby={errors.name ? "name-error" : undefined}
          placeholder="Your full name"
          required
        />
        {errors.name ? <p className="field-error" id="name-error">{errors.name}</p> : null}
      </div>

      <div className="field-group">
        <label htmlFor="email">Email</label>
        <input
          id="email"
          name="email"
          type="email"
          autoComplete="email"
          maxLength={FIELD_LIMITS.email}
          value={form.email}
          onChange={(event) => updateField("email", event.target.value)}
          aria-invalid={Boolean(errors.email)}
          aria-describedby={errors.email ? "email-error" : undefined}
          placeholder="you@example.com"
          required
        />
        {errors.email ? <p className="field-error" id="email-error">{errors.email}</p> : null}
      </div>

      <div className="field-group">
        <label htmlFor="device">Device</label>
        <select
          id="device"
          name="device"
          value={form.device}
          onChange={(event) => updateField("device", event.target.value)}
          aria-invalid={Boolean(errors.device)}
          aria-describedby={errors.device ? "device-error" : undefined}
          required
        >
          <option value="">Select your iOS device</option>
          {DEVICE_OPTIONS.map((device) => (
            <option key={device} value={device}>
              {device}
            </option>
          ))}
        </select>
        {errors.device ? <p className="field-error" id="device-error">{errors.device}</p> : null}
      </div>

      <div className="bot-field" aria-hidden="true">
        <label htmlFor="company">Company</label>
        <input
          id="company"
          name="company"
          type="text"
          tabIndex={-1}
          autoComplete="off"
          value={form.company ?? ""}
          onChange={(event) => updateField("company", event.target.value)}
        />
      </div>

      <input type="hidden" name="startedAt" value={form.startedAt ?? ""} readOnly />

      <button className="primary-action" type="submit" disabled={isSubmitting}>
        {isSubmitting ? "Submitting..." : "Request access"}
      </button>

      <p className="form-note">
        We will use your information only to manage TestFlight access and communicate about HealthSync.
      </p>

      {submission.status === "success" ? (
        <div className="status-message success" role="status">
          <span aria-hidden="true">✓</span>
          <div>
            <strong>Thanks! Your request has been received.</strong>
            <p>We will send TestFlight instructions to {submission.email} after review.</p>
            {submission.requestId ? <small>Request {submission.requestId}</small> : null}
          </div>
        </div>
      ) : null}

      {submission.status === "error" ? (
        <div className="status-message error" role="alert">
          <span aria-hidden="true">!</span>
          <div>
            <strong>Request was not submitted.</strong>
            <p>{submission.message}</p>
          </div>
        </div>
      ) : null}
    </form>
  );
}
