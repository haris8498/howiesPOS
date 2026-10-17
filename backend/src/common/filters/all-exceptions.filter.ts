import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { ApiErrorResponse } from '../types/api-response.type';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message: string | string[] = 'Internal server error';
    let errorName = 'InternalServerError';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const res = exception.getResponse();

      if (typeof res === 'string') {
        message = res;
      } else if (typeof res === 'object' && res !== null) {
        const resObj = res as Record<string, unknown>;
        message = (resObj.message as string | string[]) || exception.message;
        errorName = (resObj.error as string) || exception.name;
      }
    } else if (exception instanceof Error) {
      // Log the real error internally (never send to client)
      this.logger.error(`Unhandled Exception [${request.method} ${request.url}]: ${exception.message}`, exception.stack);
      // Return a safe generic 500 response — no internal details exposed
      message = 'Internal server error';
      errorName = 'InternalServerError';
    }

    const errorBody: ApiErrorResponse = {
      success: false,
      statusCode: status,
      message,
      error: errorName,
      timestamp: new Date().toISOString(),
      path: request.url,
    };

    response.status(status).json(errorBody);
  }
}
