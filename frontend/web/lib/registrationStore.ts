// lib/registrationStore.ts

type RegistrationData = {
  studentNo: string;
  name: string;
  surname: string;
  idNumber: string;
  phone: string;
  email: string;
  gender: string;
  password: string;
  idDocument: File | null;
  proofOfRegistration: File | null;
  acceptedTerms: boolean;
};

let registrationData: RegistrationData | null = null;
let expectedOtp: string | null = null;

export const setRegistrationData = (data: RegistrationData) => {
  registrationData = data;
};

export const getRegistrationData = (): RegistrationData | null => {
  return registrationData;
};

export const clearRegistrationData = () => {
  registrationData = null;
};

export const setExpectedOtp = (otp: string) => {
  expectedOtp = otp;
};

export const getExpectedOtp = (): string | null => {
  return expectedOtp;
};

export const clearExpectedOtp = () => {
  expectedOtp = null;
};