---
name: 😱 Regression
about: If a recent release broke a feature 😬 (Please make sure you know the last known working release version)

---

<!-- Thanks for helping _fastlane_! Before you submit your issue, please make sure to check the following boxes by putting an x in the [ ] (don't: [x ], [ x], do: [x]) -->

### New Regression Checklist

- [ ] Updated `fastlane-plugin-test_center` to the latest version
- [ ] I read the [README.md](https://github.com/lyndsey-ferguson/fastlane-plugin-test_center/blob/master/README.md)
- [ ] I reviewed the [example(s)](https://github.com/lyndsey-ferguson/fastlane-plugin-test_center/blob/master/README.md) for the action(s) I am using
- [ ] I searched for [existing GitHub issues](https://github.com/lyndsey-ferguson/fastlane-plugin-test_center/issues)
- [ ] I have removed any sensitive data such as passwords, authentication tokens, or anything else I do not want to world to see

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
zip issue-310.zip *.enc
```

Attach that zip to this issue.
-->

### Regression Information
<!-- Knowing the breaking versions and last working versions helps us track down the regression easier -->
- Breaking version: [e.g. `2.x.x`]
- Last working version: [e.g. `2.x.x`]

### Regression Description
<!-- Please include which _test_center_ action you are using. For example, multi_scan, tests_from_junit, etc. -->
<!-- Please include what's happening, expected behavior, and any relevant code samples -->

##### Complete output when running fastlane, including the stack trace and command used
<!-- You can use: `--verbose --capture_output` as the last commandline arguments to get that collected for you -->

<!-- The output of `--verbose --capture_output` could contain sensitive data such as application ids, certificate ids, or email addreses, Please make sure you double check the output and replace anything sensitive you don't wish to submit in the issue -->

<details>
  <pre>[INSERT OUTPUT HERE]</pre>
</details>

### Environment

<!-- Please run `fastlane env` and copy the output below. This will help us help you :+1:
If you used the `--capture_output` option, please remove this block as it is already included there. -->

<details>
  <pre>[INSERT OUTPUT HERE]</pre>
</details>
