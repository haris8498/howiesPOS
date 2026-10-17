import { UnauthorizedException } from '@nestjs/common';
import { JwtAuthGuard } from './jwt-auth.guard';

describe('JwtAuthGuard', () => {
  let guard: JwtAuthGuard;

  beforeEach(() => {
    guard = new JwtAuthGuard();
  });

  it('should return user when valid authenticated user is present', () => {
    const validUser = {
      id: 'usr-123',
      userId: 'usr-123',
      username: 'cashier1',
      role: 'cashier',
    };

    const result = guard.handleRequest(null, validUser);
    expect(result).toEqual(validUser);
  });

  it('should throw UnauthorizedException when user is null or undefined (no dev fallback)', () => {
    expect(() => guard.handleRequest(null, null)).toThrow(UnauthorizedException);
    expect(() => guard.handleRequest(null, undefined)).toThrow(UnauthorizedException);
    expect(() => guard.handleRequest(null, false)).toThrow(UnauthorizedException);
  });

  it('should rethrow existing error if present', () => {
    const customError = new Error('Token expired');
    expect(() => guard.handleRequest(customError, null)).toThrow(customError);
  });

  it('should never return fallback user Noman when unauthenticated', () => {
    try {
      guard.handleRequest(null, null);
      fail('Expected UnauthorizedException to be thrown');
    } catch (e: unknown) {
      expect(e).toBeInstanceOf(UnauthorizedException);
      const err = e as UnauthorizedException;
      expect(err.message).toContain('Authentication required');
    }
  });
});
