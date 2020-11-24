---
name: ❓ Support Question
about: Not sure how something works or how to implement some functionality? Ask us here! (But please check the docs first 🙃)

---

### Question Checklist

- [ ] Updated `fastlane-plugin-test_center` to the latest version
- [ ] I read the [README.md](https://github.com/lyndsey-ferguson/fastlane-plugin-test_center/blob/master/README.md)
- [ ] I reviewed the [example(s)](https://github.com/lyndsey-ferguson/fastlane-plugin-test_center/blob/master/README.md) for the action(s) I am using
- [ ] I searched for [existing GitHub issues](https://github.com/lyndsey-ferguson/fastlane-plugin-test_center/issues)

> If you love this fastlane plugin, consider sponsoring it or asking your company to sponsor it. I would really appreciate any
> gesture: https://github.com/sponsors/lyndsey-ferguson. 😍
<!--
If you have sensitive data that you do not want to be exposed, please either obfuscate that data (my-secret-token-2020202020 => my-secret-token-######) 
or encrypt it with my public key: https://github.com/lyndsey-ferguson/fastlane-plugin-test_center/files/5577804/lyndsey-ferguson-id_rsa.pub.pkcs8.zip

Refer to this article for more information: https://gist.github.com/colinstein/de1755d2d7fbe27a0f1e

Here are the relevant steps to encrypt your file(s). 

1. Create a password file that you will use to encrypt your file:
```
openssl rand 192 -out secret.txt.key
```
2. Encrypt the file with that secret key:
```
$ openssl aes-256-cbc -in <path/to/your/file> -out <path/to/your/file>.enc -pass file:secret.txt.key
```
3. Encrypt the password file with the attached public key:
```
openssl rsautl -encrypt -pubin -inkey lyndsey-ferguson-id_rsa.pub.pkcs8 -in secret.txt.key -out secret.txt.key.enc
```
4. Package up the encrypted files:
```
zip issue.zip *.enc
```

Attach that zip to this issue.
-->

### Question Subject
<!-- What tool/action do you have a question about? -->
<!-- Is this a question about documentation? -->
<!-- Is this a question about a fastlane? (If so, please go to the fastlane repository first) -->

#### Question Description
<!-- Please include expected behavior and any relevant code samples with your question if possible -->
