export interface JwtPayload {
  sub: string;
  username: string;
  role: string;
}

export interface AuthenticatedUser {
  id: string;
  username: string;
  role: string;
  is_default: boolean;
}

export interface AuthLoginData {
  accessToken: string;
  user: AuthenticatedUser;
}
