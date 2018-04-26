import Foundation
import Clibsodium

public class SecretBox {
    public let KeyBytes = Int(crypto_secretbox_keybytes())
    public let NonceBytes = Int(crypto_secretbox_noncebytes())
    public let MacBytes = Int(crypto_secretbox_macbytes())

    public typealias Key = Data
    public typealias Nonce = Data
    public typealias MAC = Data

    /**
     Generates a shared secret key.

     - Returns: The generated key.
     */
    public func key() -> Key {
        var k = Data(count: KeyBytes)
        k.withUnsafeMutableBytes { kPtr in
            crypto_secretbox_keygen(kPtr)
        }
        return k
    }

    /**
     Generates an encryption nonce.

     - Returns: The generated nonce.
     */
    public func nonce() -> Nonce {
        let nonceLen = NonceBytes
        var nonce = Data(count: nonceLen)
        nonce.withUnsafeMutableBytes { noncePtr in
            randombytes_buf(noncePtr, nonceLen)
        }
        return nonce
    }

    /**
     Encrypts a message with a shared secret key.

     - Parameter message: The message to encrypt.
     - Parameter secretKey: The shared secret key.

     - Returns: A `Data` object containing the nonce and authenticated ciphertext.
     */
    public func seal(message: Data, secretKey: Key) -> Data? {
        guard let (authenticatedCipherText, nonce): (Data, Nonce) = seal(
            message: message,
            secretKey: secretKey
        ) else { return nil }
        return nonce + authenticatedCipherText
    }

    /**
     Encrypts a message with a shared secret key.

     - Parameter message: The message to encrypt.
     - Parameter secretKey: The shared secret key.

     - Returns: The authenticated ciphertext and encryption nonce.
     */
    public func seal(message: Data, secretKey: Key) -> (authenticatedCipherText: Data, nonce: Nonce)? {
        guard secretKey.count == KeyBytes else { return nil }
        var authenticatedCipherText = Data(count: message.count + MacBytes)
        let nonce = self.nonce()

        guard .SUCCESS == authenticatedCipherText.withUnsafeMutableBytes({ authenticatedCipherTextPtr in
            message.withUnsafeBytes { messagePtr in
                nonce.withUnsafeBytes { noncePtr in
                    secretKey.withUnsafeBytes { secretKeyPtr in
                        crypto_secretbox_easy(
                            authenticatedCipherTextPtr,
                            messagePtr, UInt64(message.count),
                            noncePtr, secretKeyPtr).exitCode
                    }
                }
            }
        }) else { return nil }

        return (authenticatedCipherText: authenticatedCipherText, nonce: nonce)
    }

    /**
     Encrypts a message with a shared secret key (detached mode).

     - Parameter message: The message to encrypt.
     - Parameter secretKey: The shared secret key.

     - Returns: The encrypted ciphertext, encryption nonce, and authentication tag.
     */
    public func seal(message: Data, secretKey: Key) -> (cipherText: Data, nonce: Nonce, mac: MAC)? {
        guard secretKey.count == KeyBytes else { return nil }

        var cipherText = Data(count: message.count)
        var mac = Data(count: MacBytes)
        let nonce = self.nonce()

        guard .SUCCESS == cipherText.withUnsafeMutableBytes({ cipherTextPtr in
            mac.withUnsafeMutableBytes { macPtr in
                message.withUnsafeBytes { messagePtr in
                    nonce.withUnsafeBytes { noncePtr in
                        secretKey.withUnsafeBytes { secretKeyPtr in
                            crypto_secretbox_detached(
                                cipherTextPtr, macPtr,
                                messagePtr, UInt64(message.count),
                                noncePtr, secretKeyPtr).exitCode
                        }
                    }
                }
            }
        }) else { return nil }

        return (cipherText: cipherText, nonce: nonce, mac: mac)
    }

    /**
     Decrypts a message with a shared secret key.

     - Parameter nonceAndAuthenticatedCipherText: A `Data` object containing the nonce and authenticated ciphertext.
     - Parameter secretKey: The shared secret key.

     - Returns: The decrypted message.
     */
    public func open(nonceAndAuthenticatedCipherText: Data, secretKey: Key) -> Data? {
        guard nonceAndAuthenticatedCipherText.count >= MacBytes + NonceBytes else { return nil }
        let nonce = nonceAndAuthenticatedCipherText[..<NonceBytes] as Nonce
        let authenticatedCipherText = nonceAndAuthenticatedCipherText[NonceBytes...]

        return open(authenticatedCipherText: authenticatedCipherText, secretKey: secretKey, nonce: nonce)
    }

    /**
     Decrypts a message with a shared secret key and encryption nonce.

     - Parameter authenticatedCipherText: The authenticated ciphertext.
     - Parameter secretKey: The shared secret key.
     - Parameter nonce: The encryption nonce.

     - Returns: The decrypted message.
     */
    public func open(authenticatedCipherText: Data, secretKey: Key, nonce: Nonce) -> Data? {
        guard authenticatedCipherText.count >= MacBytes else { return nil }
        var message = Data(count: authenticatedCipherText.count - MacBytes)

        guard .SUCCESS == message.withUnsafeMutableBytes({ messagePtr in
            authenticatedCipherText.withUnsafeBytes { authenticatedCipherTextPtr in
                nonce.withUnsafeBytes { noncePtr in
                    secretKey.withUnsafeBytes { secretKeyPtr in
                        crypto_secretbox_open_easy(
                            messagePtr,
                            authenticatedCipherTextPtr, UInt64(authenticatedCipherText.count),
                            noncePtr, secretKeyPtr).exitCode
                    }
                }
            }
        }) else { return nil }

        return message
    }

    /**
     Decrypts a message with a shared secret key, encryption nonce, and authentication tag.

     - Parameter cipherText: The encrypted ciphertext.
     - Parameter secretKey: The shared secret key.
     - Parameter nonce: The encryption nonce.

     - Returns: The decrypted message.
     */
    public func open(cipherText: Data, secretKey: Key, nonce: Nonce, mac: MAC) -> Data? {
        guard nonce.count == NonceBytes,
              mac.count == MacBytes,
              secretKey.count == KeyBytes
        else { return nil }

        var message = Data(count: cipherText.count)

        guard .SUCCESS == message.withUnsafeMutableBytes({ messagePtr in
            cipherText.withUnsafeBytes { cipherTextPtr in
                mac.withUnsafeBytes { macPtr in
                    nonce.withUnsafeBytes { noncePtr in
                        secretKey.withUnsafeBytes { secretKeyPtr in
                            crypto_secretbox_open_detached(
                                messagePtr,
                                cipherTextPtr, macPtr, UInt64(cipherText.count),
                                noncePtr, secretKeyPtr).exitCode
                        }
                    }
                }
            }
        }) else { return nil }

        return message
    }
}
