# Dehydrated Netlify DNS Hook

Hook for [dehydrated](https://github.com/dehydrated-io/dehydrated) to allow DNS-01 challenges to be completed with Netlify as the DNS provider. Requires a Netlify personal access token for API requests: https://app.netlify.com/user/applications#personal-access-tokens

## Dependencies
* curl
* Python 3

## Example usage
Make sure to set `NETLIFY_TOKEN` on line 10.

```/path/to/dehydrated -c -k /path/to/dns-01-netlify.sh```
