import { Logger, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import * as express from 'express';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { AppConfig } from './config/configuration';

async function bootstrap(): Promise<void> {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule);

  const configService = app.get(ConfigService);
  const appConfig = configService.get<AppConfig>('app');

  const port = appConfig?.port || 3000;
  const apiPrefix = appConfig?.apiPrefix || 'api';
  const corsOrigin = appConfig?.corsOrigin || '*';

  // Security Headers via Helmet
  app.use(
    helmet({
      contentSecurityPolicy: false, // Keep false for Swagger UI compatibility
      crossOriginEmbedderPolicy: false,
    }),
  );

  // Request Payload Limits
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Global Prefix
  app.setGlobalPrefix(apiPrefix);

  // Global Validation Pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: {
        enableImplicitConversion: true,
      },
    }),
  );

  // Global Exception Filter
  app.useGlobalFilters(new AllExceptionsFilter());

  // CORS Configuration
  const isWildcardCors = corsOrigin === '*';
  const nodeEnv = appConfig?.nodeEnv || 'development';
  if (isWildcardCors && nodeEnv !== 'development') {
    logger.warn(
      '⚠️  SECURITY WARNING: CORS_ORIGIN is set to "*" (allow all). ' +
      'Restrict CORS_ORIGIN to specific origins before deploying to production.',
    );
  }
  app.enableCors({
    origin: isWildcardCors ? true : corsOrigin,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    credentials: true,
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'X-Requested-With'],
  });

  // Swagger / OpenAPI Specification
  const swaggerConfig = new DocumentBuilder()
    .setTitle("Hungry Howie's POS API")
    .setDescription(
      "Enterprise REST & Real-Time WebSocket API for Hungry Howie's Point-of-Sale, Kitchen Display System (KDS), Dispatch, Inventory, and Store Operations.",
    )
    .setVersion('1.0.0')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        name: 'Authorization',
        description: 'Enter your JWT access token (Bearer <token>)',
        in: 'header',
      },
      'JWT-auth',
    )
    .addTag('Auth', 'Authentication, JWT issuance, and login operations')
    .addTag('Staff', 'Staff profile management, shift assignment, and payroll status')
    .addTag('Users', 'Store user credentials, account management, and password update')
    .addTag('Permissions', 'Role-based access control (RBAC) permission matrix')
    .addTag('Menu Categories', 'Food & beverage category management')
    .addTag('Menu Items', 'Dishes, base pricing, and inventory associations')
    .addTag('Menu Sizes', 'Item size variations and pricing tiers')
    .addTag('Menu Options', 'Custom crusts and extra topping options')
    .addTag('Menu Deals', 'Combo meal packages and promotional bundle pricing')
    .addTag('Customers', 'Customer directory, loyalty points, and purchase history')
    .addTag('Orders', 'POS order lifecycle, itemized billing, taxes, and service charges')
    .addTag('Tables', 'Floor layouts, dine-in table assignment, and reservations')
    .addTag('Delivery Riders', 'Rider profiles, vehicle registration, and status')
    .addTag('Delivery Zones', 'Territory zones and delivery fee configurations')
    .addTag('Delivery Dispatches', 'Live driver dispatch tracking and order fulfillment')
    .addTag('Inventory', 'Stock catalog, minimum threshold alerts, and ledger audit movements')
    .addTag('Expenses', 'Store financial outflows, categorized expenses, and audit notes')
    .addTag('Settings', 'Global single-row store configuration, tax rates, and brand metadata')
    .addTag('Kitchen', 'Kitchen Display System (KDS) order queues, cooking timers, and KOT')
    .addTag('Reports', 'Executive analytics, product performance matrix, and P&L summaries')
    .addTag('Health', 'Service connectivity and database/Redis health probes')
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup(`${apiPrefix}/docs`, app, document, {
    swaggerOptions: {
      persistAuthorization: true,
      docExpansion: 'none',
      filter: true,
    },
    customSiteTitle: "Hungry Howie's POS - API Documentation",
  });

  await app.listen(port);
  logger.log(`🚀 Hungry Howie's POS Backend running on: http://localhost:${port}/${apiPrefix}`);
  logger.log(
    `📚 Swagger OpenAPI documentation available at: http://localhost:${port}/${apiPrefix}/docs`,
  );
  logger.log(`🩺 Health check available at: http://localhost:${port}/${apiPrefix}/health`);
}

void bootstrap();
