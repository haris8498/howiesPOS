export interface AppConfig {
  nodeEnv: string;
  port: number;
  apiPrefix: string;
  corsOrigin: string | string[];
}

export default (): { app: AppConfig } => ({
  app: {
    nodeEnv: process.env.NODE_ENV || 'development',
    port: parseInt(process.env.PORT || '3000', 10),
    apiPrefix: process.env.API_PREFIX || 'api',
    corsOrigin: process.env.CORS_ORIGIN === '*' ? '*' : (process.env.CORS_ORIGIN || '*').split(','),
  },
});
