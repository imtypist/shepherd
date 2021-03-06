# Secure Channel in OE SDK

  As Open Enclave SDK is getting adopted into more realistic scenarios, we are receiving requests from OE SDK developers for adding secure channel support.

  We do have the attestation sample that shows how to conduct remote attestation between two enclaves and establish a `proprietary` channel based on asymmetric keys exchanged during the attestation process. It demonstrates how to conduct mutual attestation but it does not go all the way to show how to establish a fully secure channel.

  Most of the real world software uses TLS-like standard protocol through popular TLS APIs (OpenSSL, WolfSSL, Mbedtls...) for establishing secure channels. Thus, instead of inventing a new communication protocol, we implemented `Attested TLS` feature to address above customer need by adding a set of new OE SDK APIs to help seamlessly integrate remote attestation into the popular TLS protocol for establishing an TLS channel with attested connecting party without modifying existing TLS APIs (such as OpenSSL, Mbedtls, and others).

# What is an Attested TLS channel

The remote attestation feature that comes with TEE (such as Intel SGX or ARM's TrustZone enclave, in the context of this doc) could significantly improve a TLS endpoint's (client or server) trustworthiness for a TLS connection starting or terminating inside an enclave. An Attested TLS channel is a TLS channel that integrates remote attestation validation as part of the TLS channel establishing process. Once established, it guarantees that an attested connecting party is running inside a TEE with expected identity.

There are two types of Attested TLS connections:
1. Both ends of an Attested TLS channel terminate inside TEE
    - Guarantee that both parties of a TLS channel are running inside trustes TEEs
    - OE SDK sample: attested_tls\client
2. Only one end of an Attested TLS channel terminate inside TEE
    - In this case, the assumption is that the end not terminated inside an TEE is a trust party. The most common use case is, this non-TEE party might have secrets to securely share with the other party through an Attested TLS channel.
    - OE SDK sample: attested_tls\non_enc_client

## Prerequisites

  The audience is assumed to be familiar with:

  - [Transport Layer Security (TLS)](https://en.wikipedia.org/wiki/Transport_Layer_Security) a cryptographic protocol designed to provide communications security over a computer network.

  - [Open Enclave Attestation](https://github.com/openenclave/openenclave/tree/master/samples/attestation#what-is-attestation): Attestation is the concept of a HW entity or of a
combination of HW and SW gaining the trust of a remote provider or producer.

### How it works

  By taking advantage of the fact that TLS involving parties use public-key cryptography for identity authentication during the [TLS handshaking process](https://en.wikipedia.org/wiki/Transport_Layer_Security#TLS_handshake), the Attested TLS feature uses a self-signed X509.V3 certificate to represent a TLS endpoint's identity. We make this certificate cryptographically bound to this specific enclave instance by adding a custom certificate extension (called quote extension) with this enclave's attestation quote that has the certificate's public key information embedded.

  In order to generate a self-signed certificate for use in the TLS handshaking process, call API `oe_get_attestation_certificate_with_evidence_v2()`.

#### Generate TLS certificate

  A connecting party needs to provide a key pair for the `oe_get_attestation_certificate_with_evidence_v2()` api to produce a self-signed certificate. These keys could be transient keys and unique for each new TLS connection.
  - a private key (pkey): used for generating a certificate and represent the identity of the TLS connecting party
  - a public key (pubkey): used in the TLS handshake process to create a digital signature in every TLS connection,

```
/**
 * oe_get_attestation_certificate_with_evidence_v2
 *
 * Similar to oe_get_attestation_certificate_with_evidence, this function
 * generates a self-signed x.509 certificate with embedded evidence generated by
 * an attester plugin for the enclave, but it also allows a user to pass in
 * optional parameters.
 *
 * @experimental
 *
 * @param[in] format_id The format id of the evidence to be generated.
 *
 * @param[in] subject_name a string containing an X.509 distinguished
 * name (DN) for customizing the generated certificate. This name is also used
 * as the issuer name because this is a self-signed certificate
 * See RFC5280 (https://tools.ietf.org/html/rfc5280) for details
 * Example value "CN=Open Enclave SDK,O=OESDK TLS,C=US"
 *
 * @param[in] private_key a private key used to sign this certificate
 * @param[in] private_key_size The size of the private_key buffer
 * @param[in] public_key a public key used as the certificate's subject key
 * @param[in] public_key_size The size of the public_key buffer.
 * @param[in] optional_parameters The optional format-specific input parameters.
 * @param[in] optional_parameters_size The size of optional_parameters in bytes.
 *
 * @param[out] output_cert a pointer to buffer pointer
 * @param[out] output_cert_size size of the buffer above
 *
 * @return OE_OK on success
 */
oe_result_t oe_get_attestation_certificate_with_evidence_v2(
    const oe_uuid_t* format_id,
    const unsigned char* subject_name,
    uint8_t* private_key,
    size_t private_key_size,
    uint8_t* public_key,
    size_t public_key_size,
    const void* optional_parameters,
    size_t optional_parameters_size,
    uint8_t** output_certificate,
    size_t* output_certificate_size);
```
#### Authenticate peer certificate

Upon receiving a certificate from the peer endpoint, a connecting party needs to perform peer certificate validation.

In this feature, instead of using the TLS API's default authentication routine, which validates the certificate against a pre-determined CAs for authentication, an application needs to conduct "Extended custom certificate validation" inside the peer custom certificate verification callback (`cert_verify_callback`), which is supported by all the popular TLS APIs.

```
For example:

    Mbedtls:
            void mbedtls_ssl_conf_verify(
                      mbedtls_ssl_config *conf,
                      int(*f_vrfy)(void *, mbedtls_x509_crt *, int, uint32_t *)
                      void *p_vrfy)

    OpenSSL:
            void SSL_CTX_set_verify(
                      SSL_CTX *ctx, int mode,
                      int (*verify_callback)(int, X509_STORE_CTX *))
```
##### Custom extended certificate validation

The following three validation steps are performed inside `cert_verify_callback`:
  1. Validate certificate.
     - Verify the signature of the self-signed certificate to ascertain that the attestation evidence is genuine and unmodified.
  2. Validate the evidence.
     - Extract this evidence extension from the certificate and perform evidence validation.
  3. Validate peer enclave's identity.
     - Validate the enclave???s identity (e.g., MRENCLAVE in SGX) against the expected list. This check ensures only the intended party is allowed to connect to.

  An OE API, `oe_verify_attestation_certificate_with_evidence()`, was added to perform step 1-2 and leaving step 3 to application for business logic, which can be done inside a caller-registered callback, `enclave_identity_callback`, a callback parameter to `oe_verify_attestation_certificate_with_evidence()` call. The API then calls another OE API, `oe_verify_attestation_certificate_with_evidence_v2()`, which was added in order to take endorsements and policies as input.

  A caller wants to fail `cert_verify_callback` with non-zero code if either certificate signature validation failed or unexpected TEE identity was found. This failure return will cause the TLS handshaking process to terminate immediately, thus preventing establishing connection with an unqualified connecting party.

```
/**
 * Type definition for a claims verification callback.
 *
 * @param[in] claims a pointer to an array of claims
 * @param[in] claims_length length of the claims array
 * @param[in] arg caller defined context
 */
typedef oe_result_t (*oe_verify_claims_callback_t)(
    oe_claim_t* claims,
    size_t claims_length,
    void* arg);

/**
 * oe_verify_attestation_certificate_with_evidence
 *
 * This function performs a custom validation on the input certificate. This
 * validation includes extracting an attestation evidence extension from the
 * certificate before validating this evidence. An optional
 * claim_verify_callback could be passed in for a calling client to further
 * validate the claims of the enclave creating the certificate.
 * OE_FAILURE is returned if the expected certificate extension OID is not
 * found.
 * @param[in] cert_in_der a pointer to buffer holding certificate contents
 *  in DER format
 * @param[in] cert_in_der_len size of certificate buffer above
 * @param[in] claim_verify_callback callback routine for custom claim checking
 * @param[in] arg an optional context pointer argument specified by the caller
 * when setting callback
 * @retval OE_OK on a successful validation
 * @retval OE_VERIFY_FAILED on quote failure
 * @retval OE_INVALID_PARAMETER At least one parameter is invalid
 * @retval OE_FAILURE general failure
 * @retval other appropriate error code
 */
oe_result_t oe_verify_attestation_certificate_with_evidence(
    uint8_t* cert_in_der,
    size_t cert_in_der_len,
    oe_verify_claims_callback_t claim_verify_callback,
    void* arg);
```
   Once the received certificate passed above validation, the TLS handshaking process can continue until an connection is established. Once connected, a connecting party can be confident that the other connecting party is indeed a specific enclave image running inside a TEE.

In the case of establishing a Attested TLS channel between two enclaves, the same authentication process could be applied to both directions in the TLS handshaking process to establish an mutually attested TLS channel between two enclaves.

 Please see OE SDK samples for how to use those new APIs along with your favorite TLS library.
