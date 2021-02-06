package utils

import (
	"errors"
	"fmt"
	"github.com/pkg/sftp"
	"golang.org/x/crypto/ssh"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/user"
	"time"
	-
)

var (
	DefaultSShTcpTimeout = 15 * time.Second
)

// 错误定义
var (
	InvalidHostName = errors.New("invalid parameters: hostname is empty")
	InvalidPort     = errors.New("invalid parameters: port must be range 0 ~ 65535")
)

// 返回当前用户名
func getCurrentUser() string {
	user, _ := user.Current()
	return user.Username
}

// 上传或下载的信息
type TransferInfo struct {
	Kind		 string   // upload或download
	Local        string   // 本地路径
	Dst          string   // 目标路径
	TransferByte int64    // 传输的字节数(byte)
}

func (t *TransferInfo) String()  string {
	return fmt.Sprintf(
		`TransforInfo(Kind:"%s", Local: "%s", Dst: "%s", TransferByte: %d)`,
		t.Kind, t.Local, t.Dst, t.TransferByte)
}

type ExecInfo struct {
	Cmd		 string
	Output	 []byte
	ExitCode int
}

func (e *ExecInfo) OutputString() string {
	return string(e.Output)
}

func (e *ExecInfo) String() string {
	return fmt.Sprintf(`ExecInfo(cmd: "%s", exitcode: %d)`,
		e.Cmd, e.ExitCode)
}

type AuthConfig struct {
	*ssh.ClientConfig
	User     string
	Password string
	KeyFile  string
	Timeout  time.Duration
}

func (a *AuthConfig) setDefault()  {
	if a.User == "" {
		a.User = getCurrentUser()
	}

	if a.KeyFile == "" {
		userHome, _ := os.UserHomeDir()
		a.KeyFile = fmt.Sprintf("%s/.ssh/id_rsa", userHome)
	}

	if a.Timeout == 0 {
		a.Timeout = DefaultSShTcpTimeout
	}
}

func (a *AuthConfig) SetAuthMethod() (ssh.AuthMethod, error) {
	a.setDefault()
	if a.Password != "" {
		return ssh.Password(a.Password), nil
	}
	data, err := ioutil.ReadFile(a.KeyFile)
	if err != nil {
		return nil, err
	}
	singer, err := ssh.ParsePrivateKey(data)
	if err != nil {
		return nil, err
	}
	return ssh.PublicKeys(singer), nil
}

func (a *AuthConfig) ApplyConfig() error {
	authMethod, err := a.SetAuthMethod()
	if err != nil {
		return err
	}
	a.ClientConfig = &ssh.ClientConfig{
		User: a.User,
		Auth: []ssh.AuthMethod{authMethod},
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		Timeout: a.Timeout,
	}
	return nil
}

type conn struct {
	client     *ssh.Client
	sftpClient *sftp.Client
}

func (c *conn) Close()  {
	if c.sftpClient != nil {
		c.sftpClient.Close()
		c.sftpClient = nil
	}
	if c.client != nil {
		c.client.Close()
		c.client = nil
	}
}

type SSHClient struct {
	conn
	HostName   string
	Port 	   int
	AuthConfig AuthConfig
}

func (s *SSHClient) setDefaultValue()  {
	if s.Port == 0 {
		s.Port = 22
	}
}

// 与远程主机连接
func (s *SSHClient) Connect() error {
	if s.client != nil {
		log.Println("Already Connect!")
		return nil
	}
	if err := s.AuthConfig.ApplyConfig(); err != nil {
		return err
	}
	s.setDefaultValue()
	addr := fmt.Sprintf("%s:%d", s.HostName, s.Port)
	var err error
	s.client, err = ssh.Dial("tcp", addr, s.AuthConfig.ClientConfig)
	if err != nil {
		return err
	}
	return nil
}

// 一个session只能执行一次命令，也就是说不能在同一个session执行多次s.session.CombinedOutput
// 如果想执行多次，需要每条为每个命令创建一个session
// 这里每次都打开一个session
func (s *SSHClient) Exec(cmd string) (*ExecInfo, error) {
	session, err := s.client.NewSession()
	if err != nil {
		return nil, err
	}
	defer session.Close()
	output, err := session.CombinedOutput(cmd)
	var exitcode int
	if err != nil {
		// 断言转成具体实现类型，获取返回值
		exitcode = err.(*ssh.ExitError).ExitStatus()
	}
	return &ExecInfo{
		Cmd: cmd,
		Output: output,
		ExitCode: exitcode,
	}, nil
}

// 将本地文件上传到远程主机上
func (s *SSHClient) Upload(localPath string, dstPath string) (*TransferInfo, error) {
	transferInfo := &TransferInfo{Kind: "upload", Local: localPath, Dst: dstPath, TransferByte: 0}
	var err error
	if s.sftpClient == nil {
		if s.sftpClient, err = sftp.NewClient(s.client); err != nil {
			return transferInfo, err
		}
	}
	localFileObj, err := os.Open(localPath)
	if err != nil {
		return transferInfo, err
	}
	defer localFileObj.Close()

	dstFileObj, err := s.sftpClient.Create(dstPath)
	if err != nil {
		return transferInfo, err
	}
	defer dstFileObj.Close()

	written, err := io.Copy(dstFileObj, localFileObj)
	if err != nil {
		return transferInfo, err
	}
	transferInfo.TransferByte = written
	return transferInfo, nil
}

// 从远程主机上下载文件到本地
func (s *SSHClient) Download(dstPath string, localPath string)  (*TransferInfo, error) {
	transferInfo := &TransferInfo{Kind: "download", Local: localPath, Dst: dstPath, TransferByte: 0}
	var err error
	if s.sftpClient == nil {
		if s.sftpClient, err = sftp.NewClient(s.client); err != nil {
			return transferInfo, err
		}
	}
	//defer s.sftpClient.Close()
	localFileObj, err := os.Create(localPath)
	if err != nil {
		return transferInfo, err
	}
	defer localFileObj.Close()

	dstFileObj, err := s.sftpClient.Open(dstPath)
	if err != nil {
		return transferInfo, err
	}
	defer dstFileObj.Close()

	written, err := io.Copy(localFileObj, dstFileObj)
	if err != nil {
		return transferInfo, err
	}
	transferInfo.TransferByte = written
	return transferInfo, nil
}

// 构造一个sshClient对象并连接远程主机，可以在远程主机上执行命令、上传和下载文件
func NewSSHClient(hostname string, port int, authConfig AuthConfig) (*SSHClient, error) {
	switch {
	case hostname == "":
		return nil, InvalidHostName
	case port > 65535 || port < 0:
		return nil, InvalidPort
	}
	sshClient := &SSHClient{HostName: hostname, Port: port, AuthConfig: authConfig}
	err := sshClient.Connect()
	if err != nil {
		return nil, err
	}
	return sshClient, nil
}
