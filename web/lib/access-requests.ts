export const DEVICE_OPTIONS = [
  "iPhone 16 or newer",
  "iPhone 15 / 15 Pro",
  "iPhone 14 or older",
  "iPad",
  "Other iOS device"
] as const;

export type DeviceOption = (typeof DEVICE_OPTIONS)[number];

export type AccessRequestInput = {
  name: string;
  email: string;
  device: DeviceOption | "";
  company?: string;
  startedAt?: string;
};

export type AccessRequest = {
  name: string;
  email: string;
  device: DeviceOption;
};

export type AccessRequestErrors = Partial<Record<keyof AccessRequestInput, string>>;

export const FIELD_LIMITS = {
  name: 80,
  email: 254
} as const;

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const DEVICE_OPTION_SET = new Set<string>(DEVICE_OPTIONS);

function toTrimmedString(value: unknown) {
  return String(value ?? "").trim().replace(/\s+/g, " ");
}

export function normalizeAccessRequestPayload(payload: unknown): AccessRequestInput {
  const record = payload && typeof payload === "object" ? (payload as Record<string, unknown>) : {};

  return {
    name: toTrimmedString(record.name),
    email: toTrimmedString(record.email).toLowerCase(),
    device: toTrimmedString(record.device) as DeviceOption | "",
    company: toTrimmedString(record.company),
    startedAt: toTrimmedString(record.startedAt)
  };
}

export function validateAccessRequest(input: AccessRequestInput):
  | { ok: true; value: AccessRequest }
  | { ok: false; errors: AccessRequestErrors } {
  const errors: AccessRequestErrors = {};

  if (input.name.length < 2) {
    errors.name = "Enter your name.";
  } else if (input.name.length > FIELD_LIMITS.name) {
    errors.name = `Use ${FIELD_LIMITS.name} characters or fewer.`;
  }

  if (!EMAIL_PATTERN.test(input.email)) {
    errors.email = "Enter a valid email address.";
  } else if (input.email.length > FIELD_LIMITS.email) {
    errors.email = `Use ${FIELD_LIMITS.email} characters or fewer.`;
  }

  if (!DEVICE_OPTION_SET.has(input.device)) {
    errors.device = "Choose the iOS device you will use for testing.";
  }

  if (Object.keys(errors).length > 0) {
    return { ok: false, errors };
  }

  return {
    ok: true,
    value: {
      name: input.name,
      email: input.email,
      device: input.device as DeviceOption
    }
  };
}
