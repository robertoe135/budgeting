import { Configuration, PlaidApi, PlaidEnvironments } from 'plaid';
import { config } from './config.js';

const basePath = PlaidEnvironments[config.plaid.env];
if (!basePath) {
  throw new Error(`Unknown PLAID_ENV "${config.plaid.env}" — expected sandbox, development, or production.`);
}

const plaidConfig = new Configuration({
  basePath,
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': config.plaid.clientId,
      'PLAID-SECRET': config.plaid.secret
    }
  }
});

export const plaidClient = new PlaidApi(plaidConfig);
