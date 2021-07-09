package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strings"
)

var DBfile = "/tmp/dbuser.db"

// 初始化数据库文件，没有就创建
func init()  {
	if _, err := os.Stat(DBfile); err != nil {
		if os.IsNotExist(err) {
			f, _ := os.Create(DBfile)
			defer f.Close()
		}
	}
}

// Input 从标准输入获取输入，以换行作为分隔, 并切除换行符，返回最终的输入字符串
func Input() string {
	stdin := bufio.NewReader(os.Stdin)
	input, _ := stdin.ReadString('\n')
	return strings.Trim(input, "\n")
}

type UserDB struct {
	DBfile string
}

// AddUser 添加用户到数据库文件
func (u *UserDB) AddUser(userinfo string) error {
	fObj, err := os.OpenFile(DBfile, os.O_RDWR|os.O_APPEND, 0644)
	if err != nil {
		return err
	}
	defer fObj.Close()
	reader := bufio.NewReader(fObj)
	// 先读取文件到末尾
	for {
		_, err := reader.ReadString('\n')
		if err == io.EOF {
			break
		}
	}
	writer := bufio.NewWriter(fObj)
	writer.WriteString(userinfo + "\n")
	writer.Flush()
	return nil
}

// FindUser 查找用户
func (u *UserDB) FindUser(username, passwd string) ([]string, error) {
	userinfo := make([]string, 0)
	db, err := u.loadDB()
	if err != nil {
		return userinfo, err
	}
	for _, val := range db {
		info := strings.Split(val, ",")
		if username == info[0] && passwd == info[1] {
			val = strings.Trim(val, "\n")
			userinfo = append(userinfo, val)
		}
	}
	return userinfo, nil
}

// 从读取文件中的用户信息
func (u *UserDB) loadDB() ([]string, error) {
	userinfo := make([]string, 0)
	fObj, err := os.Open(DBfile)
	if err != nil {
		return userinfo, err
	}
	defer fObj.Close()
	reader := bufio.NewReader(fObj)
	for {
		line, err := reader.ReadString('\n')
		if err == io.EOF {
			break
		}
		userinfo = append(userinfo, line)
	}
	return userinfo, nil
}

// 从读取文件中的用户信息
func (u *UserDB) FindFriendByGender(gender string) ([]string, error) {
	userinfo := make([]string, 0)
	db, err := u.loadDB()
	if err != nil {
		return userinfo, err
	}
	for _, val := range db {
		val = strings.Trim(val, "\n")
		info := strings.Split(val, ",")
		if info[2] != gender {
			userinfo = append(userinfo, val)
		}
	}
	return userinfo, nil
}

// NewUserDB 工厂函数，返回用户数据库信息结构体指针
func NewUserDB(DBfile string) *UserDB {
	return &UserDB{DBfile: DBfile}
}

func Menu() {
	var k []int = []int{1, 2, 3}
	menu := map[int]string{
		1: "登录",
		2: "注册",
		3: "退出",
	}
	for _, item := range k {
		fmt.Printf("%d: %s\n", item, menu[item])
	}
}

func main() {
	for {
		UserDB := NewUserDB(DBfile)
		fmt.Println("-------------- 欢迎来到交友网站 -----------------")
		Menu()
		fmt.Print("请选择：")
		choose := Input()
		// 登录
		if choose == "1" {
			fmt.Print("请输入用户名: ")
			user := Input()
			fmt.Print("请输入密码: ")
			passwd := Input()
			info, err := UserDB.FindUser(user, passwd)
			if err != nil {
                fmt.Println("获取数据错误")
                continue
            } else if len(info) == 0 {
                fmt.Println("用户或密码错误")
                continue
            }
            userinfo := strings.Split(info[0], ",")
            // 获取性别
            gender := userinfo[2]
            friends, _ := UserDB.FindFriendByGender(gender)
            fmt.Println("----------------------------------")
            fmt.Println("为你匹配到下面的朋友：")
			for i, v := range friends {
				fmt.Println(i, v)
			}
        // 注册
		} else if choose == "2" {
			fmt.Print("请输入用户名,密码,性别(用分号分隔), 如zhangshan,abc123,男: ")
			userInfo := Input()
			UserDB.AddUser(userInfo)
		} else if choose == "3" {
		    break
        } else {
			fmt.Println("不存在的选项")
		}
	}
}
