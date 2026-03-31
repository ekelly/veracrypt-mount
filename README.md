# VeraCrypt-Mount

This Docker image allows you to mount VeraCrypt encrypted volumes into Docker containers. It supports mounting both single and multiple subdirectories within the encrypted volume. This image can be used in combination with other containers to secure their data using VeraCrypt encryption.

Feeling excited? Let's dive in! 🚀

## Usage

### Prerequisites

- Install [Docker](https://www.docker.com/)
- Create a VeraCrypt encrypted volume (file container or disk partition)

### Pull the Image

Pull the `veracrypt-mount` image from Docker Hub:

```
docker pull ekelly/veracrypt-mount:latest
```

### Docker Example

In this example, we will mount a VeraCrypt encrypted file container and bind mount the decrypted content to a local directory on the host. It's as simple as a walk in the park! 🌳

1. Create a local directory for the decrypted content:

```
mkdir /path/to/decrypted
```

2. Run the `veracrypt-mount` container:

```
docker run --rm
-e VERACRYPT_PASSWORD=<your_veracrypt_password>
-e VERACRYPT_SUBDIRECTORIES="subdir1,subdir2,subdir3"
-e FILESYSTEM="exfat" 
-v /path/to/encrypted-file:/encrypted-file
-v /path/to/decrypted:/decrypted
ekelly/veracrypt-mount:latest
```

Replace `<your_veracrypt_password>` with the password for your VeraCrypt volume. Set `VERACRYPT_SUBDIRECTORIES` to a comma-separated list of subdirectories inside the encrypted volume that you want to mount. Adjust the volume paths as needed.

### Docker Compose Example

In this example, we will use a `docker-compose.yml` file to mount a VeraCrypt encrypted file container and share the decrypted content with other containers. Trust us, it's easier than it sounds! 🎉

1. Create a `docker-compose.yml` file:

```yaml
version: '3.8'

services:
  veracrypt:
    image: ekelly/veracrypt-mount:latest
    environment:
      - VERACRYPT_PASSWORD=<your_veracrypt_password>
      - FILESYSTEM=exfat # or fat, ntfs-3g, ext4
      - VERACRYPT_SUBDIRECTORIES=subdir1,subdir2,subdir3
    privileged: true # Unfortunately seems to be needed
    volumes:
      - /dev:/dev # Needed by Veracrypt 
      - /path/to/encrypted-file:/encrypted-file
      - /path/to/decrypted/mount:/decrypted:shared

  other-service:
    image: your/other-service
    volumes:
      - /path/to/decrypted/mount:/path/in/other-service:shared
    depends_on:
      - veracrypt

```

Replace `<your_veracrypt_password>` with the password for your VeraCrypt volume. Set `VERACRYPT_SUBDIRECTORIES` to a comma-separated list of subdirectories inside the encrypted volume that you want to mount. Adjust the volume paths and other service details as needed.

2. Run docker-compose up to start the containers:

```
docker-compose up -d
```

## Additional Configuration

You can customize the behavior of the veracrypt-mount container by setting environment variables:

- `VERACRYPT_PASSWORD`: The password for the VeraCrypt volume (required)
- `FILESYSTEM`: The filesystem for the VeraCrypt volume. exfat, fat, ntfs-3g, or ext4 (required)
- `VERACRYPT_SUBDIRECTORIES`: A comma-separated list of subdirectories inside the encrypted volume to mount (optional, default is to mount the entire volume)

## Contributing

If you have any questions, suggestions, or improvements, please feel free to submit an issue or pull request on the GitHub repository. Your contributions are welcome!

We hope this Docker image helps make your data more secure and your life a little bit easier. Happy encrypting! 🛡️

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/tomerh2001/veracrypt-mount/blob/main/LICENSE) file for details.

## Issues

```
[veracrypt-1] 2026-03-31T04:21:16.131792760Z Error: device-mapper: create ioctl on veracrypt1  failed: Device or resource busy
[veracrypt-1] 2026-03-31T04:21:16.131853772Z Command failed.
[veracrypt-1] 2026-03-31T04:21:16.138714985Z Error: /dev/mapper/veracrypt1 not found.
```

Run `sudo cryptsetup close veracrypt1` on the host computer
