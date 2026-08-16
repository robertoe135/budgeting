/** Plaid errors arrive as Axios errors with the useful bits in `error.response.data`. */
export function handlePlaidError(res, error, fallbackMessage) {
  const plaidError = error?.response?.data;
  if (plaidError) {
    console.error(`${fallbackMessage}:`, plaidError.error_code, plaidError.error_message);
    return res.status(502).json({
      error: fallbackMessage,
      plaidErrorCode: plaidError.error_code,
      plaidErrorMessage: plaidError.error_message
    });
  }
  console.error(fallbackMessage, error);
  return res.status(500).json({ error: fallbackMessage });
}
